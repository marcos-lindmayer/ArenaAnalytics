local _, ArenaAnalytics = ... -- Addon Namespace
local Search = ArenaAnalytics.Search;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;

-------------------------------------------------------------------------
-- Search Parsing Logic

local function CreateToken(text, isExact)
    local newToken = {}
    local tokenType, tokenValue, noSpace = Search:GetTokenPrefixKey(text);
    
    newToken["explicitType"] = tokenType;
    newToken["value"] = tokenValue;
    newToken["exact"] = isExact or nil;
    newToken["noSpace"] = noSpace;

    if(newToken["explicitType"] == "alts") then
        -- Alt searches without a slash is just a simple name type
        if(newToken["value"]:find('/') ~= nil) then
            newToken["explicitType"] = "name";
        end
    elseif(newToken["value"]:find('/') ~= nil) then -- TODO: Add support for / as a generic 'or' for values?
        newToken["explicitType"] = "alts";
    elseif(newToken["explicitType"] ~= "name") then
        -- Check for keywords
        local typeKey, valueKey, noSpace = Search:FindSearchValueDataForToken(newToken);
        if(typeKey and valueKey) then
            newToken["noSpace"] = noSpace;
            newToken["explicitType"] = typeKey;
            newToken["keyword"] = valueKey;
        elseif(not newToken["explicitType"] and newToken["value"]:find(' ') == nil) then
            -- Tokens without spaces fall back to name type
            newToken["explicitType"] = "name";
            newToken["noSpace"] = true;

            if(Search.isCommitting) then
                ArenaAnalytics:Log("Search: Forced fallback to name search type.")
            end
        end
    end

    -- Invalid token if noSpace is true while it has a space.
    if(newToken["noSpace"] and newToken["value"]:find(' ') ~= nil) then
        ArenaAnalytics:Log("CreateToken made invalid token: ", newToken["value"]);
        return nil;
    end

    if(type(newToken["value"]) == "string") then
        newToken["value"] = newToken["value"]:gsub("-", "%%-");
    end

    return newToken;
end

function Search:SanitizeInput(input)
    if(not input or input == "" or input == " ") then
        return "";
    end

    local output = input:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
    output = output:gsub("%s%s+", " ");
    return output;
end

local function SanitizeCursorPosition(input, oldCursorPosition)
    assert(input);

    if(oldCursorPosition == 0) then
        return 0;
    end

    if(oldCursorPosition == #input) then
        return -1;
    end

    local stringBeforeCursor = input:sub(1, oldCursorPosition);
    local sanitizedString = Search:SanitizeInput(stringBeforeCursor);

    return #sanitizedString;
end

local function CalculateScopeCursorIndex(currentDisplayLength, startIndex, endIndex, cursorIndex)
    if(cursorIndex >= startIndex and cursorIndex <= endIndex) then
        return currentDisplayLength + 13 + (cursorIndex - startIndex);
    end
end

-- Process the input string for symbols: Double quotation marks, commas, parenthesis, spaces
function Search:ProcessInput(input, oldCursorPosition)
    local tokenizedData = { segments = {}, nonInversedCount = 0 }

    local currentSegment = { Tokens = {}}
    local currentToken = nil;
    local currentWord = ""

    local isTokenNegated = false;

    local index = 1;

    local displayString = "";

    local newCursorPosition = 0;
    local sanitizedCursorPos = SanitizeCursorPosition(input, oldCursorPosition);
    input = Search:SanitizeInput(input);

    if(input == "") then
        return tokenizedData, displayString, input, newCursorPosition;
    end

    ----------------------------
    -- internal functions

    local function CommitCurrentSegment()
        if(currentSegment and #currentSegment.Tokens > 0) then
            if(not currentSegment.team and Options:Get("searchDefaultExplicitEnemy")) then
                currentSegment.team = "enemyTeam";
            end

            if(not currentSegment.inversed) then
                tokenizedData.nonInversedCount = tokenizedData.nonInversedCount + 1;
            end

            tinsert(tokenizedData.segments, currentSegment);
        end

        currentSegment = { Tokens = {}}
    end

    local function CommitCurrentToken()
        if(not currentToken) then
            return;
        end

        currentToken["value"] = Search:SafeToLower(currentToken["keyword"] or currentToken["value"]);
        currentToken["negated"] = isTokenNegated or nil;

        local skipInsert = false; -- Set to true for logic only keywords

        if(currentToken["explicitType"] == "logical") then
            if(currentToken["value"] == "not") then
                currentSegment.inversed = true;
                skipInsert = true;
            end
        elseif(currentToken["explicitType"] == "team") then
            if(currentToken["value"] == "team") then
                currentSegment.team = isTokenNegated and "enemyTeam" or "team";
            elseif(currentToken["value"] == "enemyteam") then
                currentSegment.team = isTokenNegated and "team" or "enemyTeam";
            end
            skipInsert = true;
        end
        
        -- Commit a real search token
        if(not skipInsert) then
            if(currentToken["value"] and currentToken["value"] ~= "") then
                tinsert(currentSegment.Tokens, currentToken);
            end
        end
        currentToken = nil;
        isTokenNegated = false;
    end

    local function CommitCurrentWord()
        if(not currentWord or currentWord == "") then
            return;
        end

        if(currentToken) then
            local combinedValue = currentToken["value"] .. " " .. currentWord;
            local newCombinedToken = CreateToken(combinedValue);
            
            if(newCombinedToken) then
                ArenaAnalytics:Log("Updating token for combined word: ", combinedValue);
                currentToken = newCombinedToken;
                currentWord = ""; -- Already added to the token
            else
                CommitCurrentToken();
            end
        end
        
        -- Might have been added to token by now
        if(currentWord ~= "") then
            currentToken = CreateToken(currentWord);

            -- Commit immediately if no space is allowed
            if(currentToken and currentToken["noSpace"]) then
                -- Commit new token immediately
                CommitCurrentToken();
            end
        end
        currentWord = "";
    end

    ----------------------------
    -- Parse the input characters

    local lastChar = nil;
    while index <= #input do
        local char = input:sub(index, index)
        
        if char == "+" then -- Disabled in favor of "team" keyword
            if (false and (#currentSegment.Tokens == 0 and currentWord == "") and lastChar ~= '+' and lastChar ~= '-') then
                currentSegment.team = "team";
                displayString = displayString .. Search:ColorizeSymbol(char);
            else
                displayString = displayString .. Search:ColorizeInvalid(char);
            end
        elseif char == '-'  and currentWord ~= "" and lastChar ~= ':' then -- Separator for name-realm
            displayString = displayString .. char;
            currentWord = currentWord .. char;
        elseif char == '!' or char == '-' then -- Negated token
            if((currentWord == "" or lastChar == ':') and lastChar ~= '!' and lastChar ~= '-') then
                CommitCurrentToken();
                isTokenNegated = true;
                displayString = displayString .. Search:ColorizeSymbol(char);
            else
                displayString = displayString .. Search:ColorizeInvalid(char);
            end
        elseif char == ' ' then
            CommitCurrentWord()
            displayString = displayString .. char;
        elseif char == ',' or char == '.' or char == ';' then
            CommitCurrentWord()
            CommitCurrentToken()
            CommitCurrentSegment()

            displayString = displayString .. Search:ColorizeSymbol(char);
        elseif char == ":" then
            CommitCurrentToken()
            currentWord = currentWord .. char;
            displayString = displayString .. Search:ColorizeSymbol(char);
        elseif char == '"' then
            local endIndex, scope, display, isNegated = Search:ProcessScope(input, index, '"');
            if endIndex then
                if(lastChar ~= ':') then
                    CommitCurrentWord();
                end
                CommitCurrentToken();

                currentToken = CreateToken(currentWord .. scope, true);
                isTokenNegated = isNegated;
                currentWord = "";

                -- Commit the new token immediately
                CommitCurrentToken();

                local cursorIndex = CalculateScopeCursorIndex(#displayString, index, endIndex, sanitizedCursorPos);
                if(cursorIndex) then
                    newCursorPosition = cursorIndex;
                end

                index = endIndex;
                
                displayString = displayString .. Search:ColorizeSymbol('"') .. display .. Search:ColorizeSymbol('"');
            else -- Invalid scope
                displayString = displayString .. Search:ColorizeInvalid(char);
            end
        elseif char == "(" then
            local endIndex, scope, display, isNegated = Search:ProcessScope(input, index, ')');
            if endIndex then
                if(lastChar ~= ':') then
                    CommitCurrentWord();
                end
                CommitCurrentToken();

                currentToken = CreateToken(currentWord .. scope);
                isTokenNegated = isNegated;
                currentWord = "";

                -- Commit the new token immediately
                CommitCurrentToken();

                local cursorIndex = CalculateScopeCursorIndex(#displayString, index, endIndex, sanitizedCursorPos);
                if(cursorIndex) then
                    newCursorPosition = cursorIndex;
                end

                index = endIndex;
                
                displayString = displayString .. Search:ColorizeSymbol('(') .. display .. Search:ColorizeSymbol(')');
            else -- Invalid scope
                displayString = displayString .. Search:ColorizeInvalid(char);
            end
        elseif char == ")" then
            -- Ignore invalid closing of scope
            displayString = displayString .. Search:ColorizeInvalid(char);
        elseif char == '/' then
            currentWord = currentWord .. char
            displayString = displayString .. Search:ColorizeSymbol(char);
        else
            currentWord = currentWord .. char
            displayString = displayString .. char;
        end

        if(index == sanitizedCursorPos) then
            newCursorPosition = #displayString;
        end
        
        lastChar = char;
        index = index + 1
    end

    -- Final commit for any remaining data
    CommitCurrentWord()
    CommitCurrentToken()
    CommitCurrentSegment()

    if(sanitizedCursorPos == -1) then
        newCursorPosition = #displayString;
    end

    return tokenizedData, displayString, input, newCursorPosition;
end

function Search:ProcessScope(input, startIndex, endSymbol)    
    local endIndex, scope, display, isNegated = nil, "", "", false;

    local lastChar = nil;
    local index = startIndex + 1;
    while index <= #input do
        local char = input:sub(index, index);

        if char == endSymbol then
            endIndex = index;
            break;
        elseif char == ',' then
            break;
        elseif char == '!' then
            if(scope == "") then
                display = display .. Search:ColorizeSymbol(char);
                isNegated = true;
            else
                display = display .. Search:ColorizeInvalid(char);
            end
        else
            scope = scope .. char;
            display = display .. char;
        end

        lastChar = char;
        index = index + 1;
    end

    return endIndex, scope, display, isNegated;
end