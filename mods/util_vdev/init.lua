local comp = component

local vdev = {}

local types = {}
local devices = {}

local unpack = unpack or table.unpack

function vdev.register_type(dtype, prototype)
  types[dtype] = prototype
end

function vdev.add_device(address, dtype)
  devices[#devices+1] = {addr=address, type=dtype}
  computer.pushSignal("component_added", address, dtype)
  return address
end

function vdev.gen_address()
  local bytes = {}
  for i=1, 16 do
    bytes[#bytes+1] = math.random(0, 255)
  end
  return string.format("%.2x%.2x%.2x%.2x-%.2x%.2x-%.2x%.2x-%.2x%.2x-%.2x%.2x%.2x%.2x%.2x%.2x", unpack(bytes))
end

function vdev.remove_device(address)
  for i=1, #devices do
    if (devices[i].addr == address) then
      computer.pushSignal("component_removed", address, devices[i].type)
      table.remove(devices, i)
      return
    end
  end
end
-- Override component library, and computer.getDeviceInfo()

local cdevinfo = computer.getDeviceInfo

component = {}

for k, v in pairs(comp) do
  component[k] = v
end

function component.list(dtype)
  local lpos = 0
  local func = comp.list(dtype)
  local ft = {}
  for k, v in pairs(func) do
    ft[k] = v
  end
  for i=1, #devices do
    if (devices[i].type:find(dtype, true) == 1) then
      ft[ devices[i].addr ] = devices[i].type
    end
  end
  return setmetatable(ft, {__call=function()
    if (lpos > #devices or #devices == 0) then
      return func()
    end
    while true do
      lpos = lpos + 1
      if (lpos > #devices) then
        return func()
      end
      if (devices[lpos].type:find(dtype, true) == 1) then
        return devices[lpos].addr
      end
    end
  end})
end

function component.proxy(addr)
  for i=1, #devices do
    if (devices[i].addr == addr) then
      return setmetatable({}, {__index=function(self, index)
        if (types[devices[i].type].methods[index]) then
          local func = setmetatable({}, {__call=function(...)
            return types[devices[i].type].methods[index](devices[i].addr, ...)
          end, __tostring = function()
            return types[devices[i].type].doc[index]
          end})
          self[index] = func
        end
      end})
    end
  end
  return comp.proxy(addr)
end

function component.invoke(addr, meth, ...)
  for i=1, #devices do
    if (devices[i].addr == addr) then
      if (types[devices[i].type][meth]) then
        types[devices[i].type].methods[meth](addr, ...)
      end
    end
  end
  return comp.invoke(addr, meth, ...)
end

function component.doc(addr, meth)
  for i=1, #devices do
    if (devices[i].addr == addr) then
      if (types[devices[i].type].methods[meth]) then
        return types[devices[i].type].doc[meth]
      end
      return
    end
  end
  return comp.doc(addr, meth)
end

function component.type(addr)
  for i=1, #devices do
    if (devices[i].addr == addr) then
      return devices[i].type
    end
  end
  return comp.type(addr)
end

function component.slot(addr)
  for i=1, #devices do
    if (devices[i].addr == addr) then
      return -1
    end
  end
  return comp.slot(addr)
end

function component.methods(addr)
  for i=1, #devices do
    if (devices[i].addr == addr) then
      local m = {}
      for k, v in pairs(types[devices[i].type].methods) do
        m[k] = true
      end
      return m
    end
  end
  return comp.methods(addr)
end

function computer.getDeviceInfo()
  local tbl = cdevinfo()
  for i=1, #devices do
    local info = {}
    tbl[devices[i].addr] = info
    local dtype = types[devices[i].type]
    info.vendor = dtype.vendor
    info.product = dtype.product
    info.class = dtype.class
    dtype.getinfo(devices[i].addr, info)
  end
  return tbl
end

return vdev