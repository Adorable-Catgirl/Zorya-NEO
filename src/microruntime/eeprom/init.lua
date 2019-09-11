local env = {}
local loadfile, _fsaddr = ...

envs.loadfile = loadfile
envs.fsaddr = _fsaddr

local fs = component.proxy(_fsaddr)
local envs = {}
-- CPIO lib
local _cpio = {}

local comp = component
local component = comp
local bit32 = bit32

local function readint(fs, handle, amt, rev)
    local tmp = 0
    for i=(rev and amt) or 1, (rev and 1) or amt, (rev and -1) or 1 do
    	tmp = bit32.bor(tmp, bit32.lshift(fs.read(handle, 1):byte(), ((i-1)*8)))
    end
    return tmp
end

--- Returns true if the file is a CPIO. False otherwises
function _cpio.validate(fs, path)
	local fs = comp.proxy(fs)
	local handle = fs.open(path, "r")
	local magic = readint(fs, handle, 2)
	if (magic == tonumber("070707", 8)) then
		return true
	end
	fs.close(handle)
	return false
end

local cpio = {}

local function cpio_index(self, file)
	local fs = self.__fs
	local handle = self.__handle
	fs.seek(hadnle, "set", 0)
	if (cpio[file]) then
		return cpio[file]
	end
	local dent = {
	    magic = 0,
	    dev = 0,
	    ino = 0,
	    mode = 0,
	    uid = 0,
	    gid = 0,
	    nlink = 0,
	    rdev = 0,
	    mtime = 0,
	    namesize = 0,
	    filesize = 0,
	}
	local found, dir
	while true do
		dent.magic = readint(fs, handle, 2)
		local rev = false
	    if (dent.magic ~= tonumber("070707", 8)) then rev = true end
	    dent.dev = readint(fs, handle, 2)
	    dent.ino = readint(fs, handle, 2)
	    dent.mode = readint(fs, handle, 2)
	    dent.uid = readint(fs, handle, 2)
	    dent.gid = readint(fs, handle, 2)
	    dent.nlink = readint(fs, handle, 2)
	    dent.rdev = readint(fs, handle, 2)
	    dent.mtime = bit32.bor(bit32.lshift(readint(fs, handle, 2), 16), readint(fs, handle, 2))
	    dent.namesize = readint(fs, handle, 2)
	    dent.filesize = bit32.bor(bit32.lshift(readint(fs, handle, 2), 16), readint(fs, handle, 2))
	    local name = fs.read(handle, dent.namesize):sub(1, dent.namesize-1)
	    if (name == "TRAILER!!!") then break end
	    dent.name = name
	    if (dent.namesize % 2 ~= 0) then
	        fs.read(handle, 1) -- skip one byte
	    end
	    if (bit32.band(dent.mode, 16384) ~= 0) then
	    	found = true
	    	dir = true
	    	break
	    end
	    if bit32.band(dent.mode, 32768) ~= 0 then -- just wait for Lua 5.3 compatibility!
	        --local dir = dent.name:match("(.+)/.*%.?.+")
	        found = true
	        break
	    end
	    if (dent.filesize % 2 ~= 0) then
	        fs.read(handle, 1) -- skip one byte
	    end
	end
	if not found then
		return nil, "file not found"
	end
	if dir then
		return dir
	end
	local dat = ""
	local fz = dent.filesize
	while true do
		dat = dat .. fs.read(handle, fz)
		fz = fz - #dat
		if (fz < 1) then
			break
		end
	end
	return dat
end

function cpio:close()
	self.__fs.close(self.__handle)
end

--- Load the cpio into a table. If value is true, then key is a directory, otherwise value is a string and key corresponds
--- to a file
function _cpio.load(fs, path)
	local arc = {__fs=component.proxy(fs)}
	arc.__handle=fs.open(path, "r")
	return setmetatable(arc, {__index=cpio_index})
end

-- Quick util function
local function get_ptable(tbl)
	return setmetatable({}, {
		__index = function(self, index)
			if (type(tbl[index] ~= "table")) then
				return tbl[index]
			else
				return get_ptable(tbl[index])
			end
		end,
		__newindex = function()
			error("table is read only")
		end
	})
end

-- Module loaders
local function loadmod_cpio(module)
	local arc = _cpio.load(".zv2/mods/"..module..".zyr")
	--Load the executable.
end

local function loadmod(module)
	--First we check for CPIO files (.zv2/mods/*.zyr), then lua files (.zv2/mods/*.zyl)
	--Then, OEFIv2.1 applications (.efi/zymod_*.efi2)
	if (fs.exists(".zv2/mods/"..module..".zyr")) then
		loadmod_cpio(module)
	elseif (fs.exists(".zv2/mods/"..module..".zvl")) then
		loadmod_raw(module)
	elseif (fs.exists(".efi/zymod_"..module..".efi")) then
		loadmod_efi2(module..".efi")
	elseif (fs.exists(".efi/zymod_"..module..".efi2")) then
		loadmod_efi2(module..".efi2")
	elseif (module == "cpio") then
		env.libraries.cpio = cpio
	end
end