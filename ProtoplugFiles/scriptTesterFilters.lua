--require('mobdebug').start()
--protoplug_path = "C:\\Lua\\protoplug\\Bin\\win32\\Lua Protoplug Gen.dll"
--protoplug_path= "/Users/JT/JUCE/protoplug/Bin/mac/Release/Lua Protoplug Gen.vst/Contents/MacOS/Lua Protoplug Gen"
--protoplug_dir  = "."
--package.path = package.path..';/Users/JT/JUCE/protoplug/ProtoplugFiles'


--require "include/protoplug"
am = require "include/audioMath"
filters = require "include/filters"
local ffi = require "ffi"

require "include/luafft" --https://github.com/vection/luafft
local gp = require('gnuplot')

--local signal = require 'signal'


local function toComplex(data, size)
    local list = {}
    for i=0, size-1 do
      list[i+1] = complex.new(data[i], 0)
    end
    return list
end


local function plot(x, y, xLabel, yLabel, Title)

  local g = gp{
      -- all optional, with sane defaults
      width  = 1024, height = 768, xlabel = xLabel, ylabel = yLabel, key    = "top left",
      consts = {gamma = 2.5},
      
      data = {
          gp.array { 
              { x, y },
              
              title = Title,          -- optional
              using = {1,2},              -- optional
              with  = 'lines'       -- optional
          }
      }    
  }:plot('graph.png')
    
end


--Apply window to data, expected to be an array of doubles or floats starting at zero
local function applyHannWindow(data, N)
  local cos = math.cos
  local pi  = math.pi
  for i=0, N-1 do
    data[i] = 0.5 * (1 - cos((2 * pi * i)/(N-1))) * data[i]
    --data[i] = 1 - ((i - (N-1)/2)/((N-1)/2))^2
  end
end

local function phaseUnwrap(list,in_tol)
  local tol = in_tol or math.pi - 0.1
  local prev = list[1]
  for i=2, #list do
    local jump = math.abs(list[i] - prev)
    if  jump > tol then
        local o1 = list[i] + math.pi - prev
        local o2 = list[i] - math.pi - prev
        if math.abs(o1) < jump and math.abs(o1) < math.abs(o2) then
          list[i] = list[i] + math.pi
        elseif math.abs(o2) < jump then
          list[i] = list[i] - math.pi
        end
    end
    prev = list[i]
  end
end


local function plotFFT(data, N, windowed)
  if windowed then
    applyHannWindow(data, N)
  end
  
  local ret = fft(toComplex(data, N))
  
  local freq      = {}
  local amplitude = {}
  local phase     = {}
  
  for i=0, N/2 do
    --freq[#freq+1]  = -0.5 + i / (N-1)
    freq[#freq+1]  = 2*i / N
    amplitude[#freq+1] = 20 * math.log10(complex.abs(ret[i+1]) / N)
  end
  
  plot(freq, amplitude, "freq", "20log|H|", "amplitude")
  --local wait = io.read()
end

local function plotSignal_Torch(data, N, from, to)
  from = from or 0
  to   = to   or N-1
  local t = {}
  local vals = {}
  j=0
  for i=from, to do
    t[j+1]    = i
    vals[j+1] = data[i]
    j = j + 1
  end
    
  require 'gnuplot'
  gnuplot.figure(1)

  gnuplot.plot('signal',torch.Tensor(t), torch.Tensor(vals),'-')
  gnuplot.xlabel('t')
  --gnuplot.ylabel('20 log |H|')
  gnuplot.ylabel('amplitude')
  local wait = io.read()
end


local function plotFFT_Torch(data, N, windowed)
  if windowed then
    applyHannWindow(data, N)
  end
  
  local function toComplex(data, size)
    local list = {}
    for i=0, size-1 do
      list[i+1] = {data[i], 0}
    end
    return torch.Tensor(list)
  end
  
  local ret = signal.fft(toComplex(data, N))
  
  local freq      = {}
  local amplitude = {}
  local phase     = {}
  
  for i=0, N/2 do
    --freq[#freq+1]  = -0.5 + i / (N-1)
    freq[#freq+1]  = 2*i / N
    amplitude[#freq] = 20 * math.log10(math.sqrt(ret[i+1][1]^2+ret[i+1][2]^2)/N)
    phase[#freq]     = math.atan(ret[i+1][2]/ret[i+1][1])
  end
  
  require 'gnuplot'
  gnuplot.figure(1)

  --gnuplot.plot('amplitude',torch.Tensor(freq), torch.Tensor(amplitude),'-')
  --Phase unwrap is broken !
  phaseUnwrap(phase)
  phase = torch.Tensor(phase)
  gnuplot.plot('phase',torch.Tensor(freq), phase,'-')
  gnuplot.xlabel('freq')
  --gnuplot.ylabel('20 log |H|')
  gnuplot.ylabel('phase')
  local wait = io.read()
  
end

local function upsample2XByBlocks(data, size)
  local blockSize = 64

  upSampler = am.X2Upsampler()
  
  outData = ffi.new("double[?]", size*2)
  
  local numBlocks = size / blockSize
  if size % blockSize ~= 0 then
    error("Size must be a multiple of blocksize", 1)
  end
  
  for b=0, numBlocks -1 do
    outSamples = upSampler(data+b*blockSize, blockSize)
    for s=0, 2*blockSize-1 do
      outData[b*2*blockSize + s] = outSamples[s]
    end
  end
  
  return outData
end

local function upsample4XByBlocks(data, size)
  local blockSize = 64

  upSampler = am.X4Upsampler()
  
  outData = ffi.new("double[?]", size*4)
  
  local numBlocks = size / blockSize
  if size % blockSize ~= 0 then
    error("Size must be a multiple of blocksize", 1)
  end
  
  for b=0, numBlocks -1 do
    outSamples = upSampler(data+b*blockSize, blockSize)
    for s=0, 4*blockSize-1 do
      outData[b*4*blockSize + s] = outSamples[s]
    end
  end
  
  return outData
end

local function downsample2XByBlocks(data, size)
  local blockSize = 64

  downsampler = am.X2Downsampler()
  
  outData = ffi.new("float[?]", size/2)
  
  local numBlocks = size / blockSize
  if size % blockSize ~= 0 then
    error("Size must be a multiple of blocksize", 1)
  end
  
  for b=0, numBlocks -1 do
    outSamples = downsampler(data+b*blockSize, blockSize)
    for s=0, blockSize/2-1 do
      outData[b*blockSize/2 + s] = outSamples[s]
    end
  end
  
  return outData
end


function X2UpsamplerTest()
  local fftSize   = 4096

  local testFrequencies = {0.5}
  local testAmplitude = 1 / #testFrequencies
  --testFrequencies = {0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.48}
  
  local data = ffi.new("float[?]", fftSize)
  
  
  for _,f in ipairs(testFrequencies) do
    for i=0, fftSize-1 do
      data[i] = data[i] + testAmplitude * math.cos(2*math.pi*f *i/2)
      --print(data[i])
    end
  end
  
  --data[0] = 1
  --Filter test:
  --[[LP = filters.SecondOrderButterworthLP(0.1)
  
  for s=0, fftSize - 1 do
    data[s] = LP(data[s])
  end

  plotFFT(data, fftSize, nil)
  --]]
  
  local upSampledData = upsample2XByBlocks(data, fftSize)
  plotFFT_Torch(upSampledData, fftSize)
  
end
function X4UpsamplerTest()
  local fftSize   = 4096

  local testFrequencies = {0.5}
  local testAmplitude = 1 / #testFrequencies
  --testFrequencies = {0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.48}
  
  local data = ffi.new("float[?]", fftSize)
  
  
  for _,f in ipairs(testFrequencies) do
    for i=0, fftSize-1 do
      data[i] = data[i] + testAmplitude * math.cos(2*math.pi*f *i/2)
      --print(data[i])
    end
  end
  
  --data[0] = 1
  --Filter test:
  --[[LP = filters.SecondOrderButterworthLP(0.1)
  
  for s=0, fftSize - 1 do
    data[s] = LP(data[s])
  end

  plotFFT(data, fftSize, nil)
  --]]
  
  local upSampledData = upsample4XByBlocks(data, fftSize)
  plotFFT(upSampledData, fftSize*4,1)
  
end
function X2DownsamplerTest()
  local fftSize   = 4096*2

  local testFrequencies = {0.4}
  local testAmplitude = 1 / #testFrequencies
  --testFrequencies = {0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.48}
  
  local data = ffi.new("double[?]", fftSize)
  
  
  for _,f in ipairs(testFrequencies) do
    for i=0, fftSize-1 do
      data[i] = data[i] + testAmplitude * math.cos(2*math.pi*f *i/2)
      --print(data[i])
    end
  end
  
  
  local downsampledData = downsample2XByBlocks(data, fftSize)
  plotFFT(downsampledData, fftSize/2,1)
  --plotSignal_Torch(downsampledData, fftSize/2,fftSize/4,fftSize/2-1)
  --plotSignal_Torch(data, fftSize, fftSize/2, fftSize-1)
  --[[local test1 = filters.SecondOrderButterworthLP(0.5)
  
  for i=0, fftSize-1 do
    data[i] = test1(data[i])
  end
  plotFFT_Torch(data, fftSize,1) --]]
  
end

X4UpsamplerTest()