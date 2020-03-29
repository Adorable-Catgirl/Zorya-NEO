_ZLOADER = "initramfs"
local readfile=function(f,h)
	local b=""
	local d,r=f.read(h,math.huge)
	if not d and r then error(r)end
	b=d
	while d do
		local d,r=f.read(h,math.huge)
		b=b..(d or "")
		if(not d)then break end
	end
	f.close(h)
	return b
end

local bfs = {}

local cfg = component.proxy(component.list("eeprom")()).getData()

local baddr = cfg:sub(1, 36)
local bootfs = component.proxy(baddr)

assert(bootfs.exists(".zy2/image.tsar"), "No boot image!")

local romfs_file = assert(bootfs.open(".zy2/image.tsar", "rb"))
local rfs = readfile(bootfs, romfs_file)

--[[local romfs_dev = tsar.read(function(a)
	local c = ""
	local d
	while a > 0 do
		d = bootfs.read(romfs_file, a)
		a = a - #d
		c = c .. d
	end
	return c
end, function(a)
	return bootfs.seek(romfs_file, "cur", a)
end, function()
	return bootfs.close(romfs_file)
end)]]
local h = 1
local romfs_dev = tsar.read(function(a)
	local d = rfs:sub(h, h+a-1)
	h = h+a
	return d
end, function(a)
	h = h + a
	return h
end, function()
	rfs = nil
end)

function bfs.getfile(path)
	return romfs_dev:fetch(path)
end

function bfs.exists(path)
	return romfs_dev:exists(path)
end

function bfs.getcfg()
	local h = assert(bootfs.open(".zy2/cfg.lua", "r"))
	return readfile(bootfs, h)
end

bfs.addr = baddr