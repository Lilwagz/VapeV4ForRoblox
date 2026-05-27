local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end
local watermark = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.'
local commitFile = 'newvape/profiles/commit.txt'
local cachedCommit

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			cachedCommit = cachedCommit or (isfile(commitFile) and readfile(commitFile) or 'main')
			return game:HttpGet('https://raw.githubusercontent.com/Lilwagz/VapeV4ForRoblox/'..cachedCommit..'/'..path:gsub('^newvape/', ''), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:sub(-4) == '.lua' then
			res = watermark..'\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') then continue end
		if isfile(file) and readfile(file):sub(1, #watermark) == watermark then
			delfile(file)
		end
	end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not shared.VapeDeveloper then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/Lilwagz/VapeV4ForRoblox')
	end)
	local commit = subbed:find('currentOid')
	commit = commit and subbed:sub(commit + 13, commit + 52) or nil
	commit = commit and #commit == 40 and commit or 'main'
	local oldCommit = isfile(commitFile) and readfile(commitFile) or ''
	if commit == 'main' or oldCommit ~= commit then
		wipeFolder('newvape')
		wipeFolder('newvape/games')
		wipeFolder('newvape/guis')
		wipeFolder('newvape/libraries')
	end
	cachedCommit = commit
	if oldCommit ~= commit then
		writefile(commitFile, commit)
	end
end

return loadstring(downloadFile('newvape/main.lua'), 'main')()
