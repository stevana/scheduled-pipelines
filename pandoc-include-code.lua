-- Based on Bruno BEAUFILS' filter:
--   https://github.com/b3/include-code-files

local function dedent (line, n)
  return line:sub(1,n):gsub(" ","") .. line:sub(n+1)
end

function CodeBlock (cb)
  if cb.attributes.include then
    local content = ""
    local fh = io.open(cb.attributes.include)
    if not fh then
      io.stderr:write("Cannot open file " .. cb.attributes.include .. " | Skipping includes\n")
    else
      local including = false
      local number = 1

      for line in fh:lines ("L")
      do
        if cb.attributes.snippet and 
           string.find(line, "start snippet " .. cb.attributes.snippet) 
        then
          including = true
          cb.attributes.startFrom = number + 1
        elseif string.find(line, "end snippet") then
          including = false
        elseif including then
          if cb.attributes.dedent then
            line = dedent(line, cb.attributes.dedent)
          end
          content = content .. line
        end
        number = number + 1
      end
      fh:close()
    end
    cb.attributes.include = nil
    cb.attributes.dedent = nil
    cb.attributes.snippet = nil
    return pandoc.CodeBlock(content, cb.attr)
  end
end
