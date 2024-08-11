local _, ArenaAnalytics = ... -- Addon Namespace
local Search = ArenaAnalytics.Search;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;

-------------------------------------------------------------------------
-- Search Parsing Logic

-- DEPRECATED: Symbols are getting added as raw within any token.
local function CreateSymbolToken(symbol)
    assert(symbol)

    local newSpaceToken = {}
    newSpaceToken.transient = true;
    newSpaceToken.explicitType = "symbol";
    newSpaceToken.raw = symbol;
    
    function newSpaceToken:GetRaw()
        return newSpaceToken.raw;
    end

    function newSpaceToken:GetDisplay()
        return newSpaceToken.raw;
    end

    return newSpaceToken;
end

local function ParseTokenString(text)
    local value = "";

    if(text and text ~= "") then
        local lastChar = '';
        local excludedChars = '+"()!'

        for i = 1, #text do
            local char = text:sub(i,i);

            if(char == '-' and lastChar ~= '' and lastChar ~= ':') then
                value = value .. char;
            elseif(not excludedChars:find(char)) then
                value = value .. char;
            end
        end
    end

    return value;
end

function Search:CreateToken(raw, isExact)
    assert(raw);
    
    local newToken = {}
    local value = ParseTokenString(raw);
    local explicitType, tokenValue, noSpace = Search:GetTokenPrefixKey(value);

    if(raw == "") then
        explicitType = "empty";
    end
    
    newToken.explicitType = explicitType;
    newToken.value = tokenValue;
    newToken.exact = isExact or nil;
    newToken.noSpace = noSpace;
    newToken.raw = raw;

    if(newToken.explicitType == "alts") then
        -- Alt searches without a slash is just a simple name type
        if(newToken.value:find('/') ~= nil) then
            newToken.explicitType = "name";
        end
    elseif(newToken.value:find('/') ~= nil) then -- TODO: Add support for / as a generic 'or' for values?
        newToken.explicitType = "alts";
    elseif(newToken.explicitType ~= "name") then
        -- Check for keywords
        local typeKey, valueKey, noSpace = Search:FindSearchValueDataForToken(newToken);
        if(typeKey and valueKey) then
            newToken.noSpace = noSpace;
            newToken.explicitType = typeKey;
            newToken.keyword = valueKey;
        elseif(not newToken.explicitType and not newToken.value:find(' ')) then
            -- Tokens without spaces fall back to name type
            newToken.explicitType = "name";
            newToken.noSpace = true;

            if(Search.isCommitting) then
                ArenaAnalytics:Log("Search: Forced fallback to name search type.")
            end
        end
    end
    
    -- Valid if it has a keyword or no spaces
    newToken.isValid = newToken.keyword or newToken.noSpace and not newToken.value:find(' ');

    if(type(newToken.value) == "string") then
        newToken.value = newToken.value:gsub("-", "%%-");
    end
    
    function newToken:GetRaw()
        return self.raw;
    end
    
    ArenaAnalytics:Log("New Token: '" .. newToken.raw .. "'", newToken.isValid);
    return newToken;
end

function Search:SanitizeInput(input)
    if(not input or input == "") then
        return "";
    end

    local output = input:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
    output = output:gsub("%s%s+", ' ');

    if(input == " ") then
        return "";
    end

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

local function IsPlayerSegmentSeparatorChar(char)
    return char == ',' or char == '.' or char == ';';
end

-- Process the input string for symbols: Double quotation marks, commas, parenthesis, spaces
function Search:ProcessInput(input, oldCursorPosition)
    local tokenizedSegments = {}

    -- Current
    local currentSegment = Search:GetEmptySegment();
    local currentToken = nil;
    local currentWord = "";
    local currentRaw = "";

    -- Whether a space has yet to be handled. Processed in CommitWord()
    local hasUnhandledSpace = nil;

    -- Caret Position Data
    local sanitizedCaretIndex = SanitizeCursorPosition(input, oldCursorPosition);
    local currentWordCaretOffset = nil; -- Cursor relative to the word it's placed in

    local isTokenNegated = false;

    local index = 1;

    local displayString = "";

    local newCursorPosition = 0;
    local sanitizedInput = Search:SanitizeInput(input);

    if(sanitizedInput == "") then
        return tokenizedSegments;
    end

    ----------------------------------------
    -- internal functions

    local function CommitCurrentSegment()
        if(currentSegment and #currentSegment.tokens > 0) then
            tinsert(tokenizedSegments, currentSegment);
        end

        currentSegment = Search:GetEmptySegment();
    end

    local function CommitCurrentToken()
        if(currentToken) then
            currentToken.value = Search:SafeToLower(currentToken.keyword or currentToken.value);
            currentToken.negated = isTokenNegated or nil;
            
            if(currentToken.explicitType == "logical") then
                if(currentToken.value == "not") then
                    currentToken.transient = true;
                end
            elseif(currentToken.explicitType == "team") then
                currentToken.transient = true;
            end
            
            -- Commit a real search token
            if(currentToken.raw) then
                tinsert(currentSegment.tokens, currentToken);
            end
            
            currentToken = nil;
            isTokenNegated = false;
        end
            
        -- Add unhandled space
        if(hasUnhandledSpace and (#tokenizedSegments > 0 or #currentSegment.tokens > 0)) then
            -- Add space symbol token
            hasUnhandledSpace = nil;
            local newSpaceToken = CreateSymbolToken(' ');
            tinsert(currentSegment.tokens, newSpaceToken);
            
            ArenaAnalytics:Log("Added unhandled space.")
        end
    end

    local function CommitCurrentWord()
        currentWord = currentWord or "";
        
        if(currentToken and currentWord ~= "") then
            local combinedValue = currentToken.value .. " " .. currentWord;
            local newCombinedToken = Search:CreateToken(combinedValue);
            
            if(newCombinedToken and newCombinedToken.isValid) then
                if(currentWordCaretOffset) then
                    -- Old token length, including space, plus the offset
                    newCombinedToken.caret = #currentToken.raw + 1 + currentWordCaretOffset;
                end

                currentToken = newCombinedToken;
                hasUnhandledSpace = nil;
                currentWord = ""; -- Already added to the token
            else
                CommitCurrentToken();
            end
        end
        
        -- Might have been added to token by now
        if(not currentToken and currentWord ~= "") then
            currentToken = Search:CreateToken(currentWord, false);

            if(currentWordCaretOffset) then
                currentToken.caret = currentWordCaretOffset;
            end

            -- Commit immediately if no space is allowed
            if(currentToken and currentToken.noSpace) then
                -- Commit new token immediately
                CommitCurrentToken();
            end
        end

        -- Reset current word
        currentWordCaretOffset = nil;
        currentWord = "";
    end

    ----------------------------------------
    -- Parse the sanitizedInput characters

    local lastChar = nil;
    while index <= #sanitizedInput do
        local char = sanitizedInput:sub(index, index);
        
        ArenaAnalytics:Log("Tokenize Parse: '" .. char .. "'", "'" .. (lastChar or '') .. "'", hasUnhandledSpace);

        -- Store the sanitized relative caret position for the token in the making
        if(index == sanitizedCaretIndex) then
            ArenaAnalytics:Log("Caret index: ", index);
            currentWordCaretOffset = #currentWord + 1;
        end
        
        if char == "+" then -- Disabled in favor of "team" keyword
            currentWord = currentWord .. char;
        elseif char == '-'  and currentWord ~= "" and lastChar ~= ':' then -- Separator for name-realm
            currentWord = currentWord .. char;
        elseif char == '!' or char == '-' then -- Negated token
            if((currentWord == "" or lastChar == ':') and lastChar ~= '!' and lastChar ~= '-') then
                CommitCurrentToken();
                isTokenNegated = true;
            end
            currentWord = currentWord .. char;

        elseif char == ' ' then
            if(#tokenizedSegments > 0 and #currentSegment.tokens == 0) then
                -- Add the space directly
                currentToken = CreateSymbolToken(char);
                CommitCurrentToken();
            else
                hasUnhandledSpace = true;
            end
                
            CommitCurrentWord();

        elseif IsPlayerSegmentSeparatorChar(char) then -- comma, period or semicolon
            CommitCurrentWord();
            CommitCurrentToken();
            
            if(#currentSegment.tokens > 0) then
                -- Add the separator at the end of the segment
                currentToken = CreateSymbolToken(char);
                CommitCurrentToken();
            end

            CommitCurrentSegment();

        elseif char == ":" then
            CommitCurrentToken()
            currentWord = currentWord .. char;

        elseif char == '"' then
            local endIndex, scope, isNegated, scopeCaretOffset = Search:ProcessScope(sanitizedInput, index, '"', sanitizedCaretIndex);
            if endIndex then
                if(lastChar ~= ':' and lastChar ~= '!' and lastChar ~= '-') then
                    CommitCurrentWord();
                end
                CommitCurrentToken();

                -- Check caret pos
                if(scopeCaretOffset) then
                    currentWordCaretOffset = scopeCaretOffset + #currentWord;
                end

                currentToken = Search:CreateToken(currentWord..scope, true);
                isTokenNegated = isNegated;
                currentWord = "";

                -- Commit the new token immediately
                CommitCurrentToken();

                index = endIndex;
            else -- Invalid scope
                currentWord = currentWord .. char;
            end

        elseif char == "(" then
            local endIndex, scope, isNegated, scopeCaretOffset = Search:ProcessScope(sanitizedInput, index, ')', sanitizedCaretIndex);
            if endIndex then
                if(lastChar ~= ':' and lastChar ~= '!' and lastChar ~= '-') then
                    CommitCurrentWord();
                end
                CommitCurrentToken();

                -- Check caret pos
                if(scopeCaretOffset) then
                    currentWordCaretOffset = #currentWord + scopeCaretOffset;
                end

                currentToken = Search:CreateToken(currentWord..scope, false);
                isTokenNegated = isNegated;
                currentWord = "";

                -- Commit the new token immediately
                CommitCurrentToken();

                index = endIndex;
                
                displayString = displayString .. Search:ColorizeSymbol('(') .. display .. Search:ColorizeSymbol(')');
            else -- Invalid scope
                currentWord = currentWord .. char;
            end

        elseif char == ")" then
            currentWord = currentWord .. char;

        elseif char == '/' then
            currentWord = currentWord .. char;

        else
            currentWord = currentWord .. char;
        end

        -- Prepare for next char
        lastChar = char;
        index = index + 1
    end
    
    ----------------------------------------
    -- Final commit for any remaining data

    CommitCurrentWord()
    CommitCurrentToken()
    CommitCurrentSegment()

    return tokenizedSegments;
end

function Search:ProcessScope(input, startIndex, endSymbol, sanitizedCaretIndex)    
    local endIndex, isNegated = nil, false;

    -- Add the scope opening char
    local scope = "";
    local scopeCaretOffset = nil;
    
    -- Loop fron next index
    local index = startIndex;
    while index <= #input do
        local char = input:sub(index, index);

        if(sanitizedCaretIndex and index == sanitizedCaretIndex) then
            scopeCaretOffset = index;
        end

        -- Add any char to the scope, except player segment separators
        if(not IsPlayerSegmentSeparatorChar(char)) then
            scope = scope .. char;
        end

        -- Check if the scope is over
        if char == endSymbol and index > startIndex then
            endIndex = index;
            break;
        elseif(IsPlayerSegmentSeparatorChar(char)) then
            break;
        end

        if(char == '!' or char == '-') and #scope <= 1 then
            isNegated = true;
        end

        index = index + 1;
    end

    return endIndex, scope, isNegated, scopeCaretOffset;
end