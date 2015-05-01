
protoplug_path = "C:\\Lua\\protoplug\\Bin\\win32\\Lua Protoplug Gen.dll"
protoplug_dir  = "."
require "include/protoplug"
am = require "include/audioMath"
filters = require "include/filters"
local ffi = require "ffi"

require "include/luafft" --https://github.com/vection/luafft
local gp = require('gnuplot')

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
    freq[#freq+1]  = i / N
    amplitude[#freq+1] = 20 * math.log10(complex.abs(ret[i+1]) / N)
  end
  
  plot(freq, amplitude, "freq", "20log|H|", "amplitude")

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

  local testFrequencies = {0.25}
  local testAmplitude = 1 / #testFrequencies
  --testFrequencies = {0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.48}
  
  local data = ffi.new("float[?]", fftSize)
  
  
  for _,f in ipairs(testFrequencies) do
    for i=0, fftSize-1 do
      data[i] = data[i] + testAmplitude * math.cos(2*math.pi*f *i)
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
  plotFFT(upSampledData, fftSize*2)
  
end
function X2DownsamplerTest()
  local fftSize   = 4096*2

  local testFrequencies = {0.26}
  local testAmplitude = 1 / #testFrequencies
  --testFrequencies = {0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.48}
  
  local data = ffi.new("double[?]", fftSize)
  
  
  for _,f in ipairs(testFrequencies) do
    for i=0, fftSize-1 do
      data[i] = data[i] + testAmplitude * math.cos(2*math.pi*f *i)
      --print(data[i])
    end
  end
  
  
  local downsampledData = downsample2XByBlocks(data, fftSize)
  plotFFT(downsampledData, fftSize/2)
  
end

X2UpsamplerTest()