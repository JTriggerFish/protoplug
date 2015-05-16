--[[
name: Circuit modeled saturator
description: >
  A saturator based on a non linear integrator with zero delay feedback.
  It is 4x oversampled and uses some dithering
  Use pregain to increase or decrease the saturation and the cutoff to change the -6db rollof point
author: JT Marin
--]]

require "include/protoplug"
am      = require "include/audiomath"
filter  = require "include/filters" 

local effects = {}

stereoFx.init()

function stereoFx.Channel:init()
	-- create per-channel fields (effects)
	self.effect =
	{ 
		sampleRate = 44100,
		-- initialize with current param values
		preGain     = params[1].getValue(),
		cutoff      = params[2].getValue(),
		ditherLevel = math.pow(10, -80 / 20) ,
		
		upSampler   = am.X4Upsampler(),
		saturator   = filter.NonLinearIntegratorZDF(),
		downSampler = am.X4Downsampler(),
	}
    function self.effect:update(dic) 
        for key, value in pairs(dic) do
            self[key] = value
        end
    end
	table.insert(effects, self.effect)
end

function stereoFx.Channel:processBlock(s, smax)
	local blockSize = smax + 1
	self.effect.sampleRate = plugin.isSampleRateKnown() and plugin.getSampleRate() or 44100
	
	for i = 0,smax do
		s[i] = self.effect.preGain * s[i]
	end
	
	local inSamples  = self.effect.upSampler(s, blockSize)
    local g          = math.tan(math.pi * self.effect.cutoff / (4* self.effect.sampleRate))
	local d          = self.effect.ditherLevel
	for i = 0, blockSize*4-1 do
        --Note the dithering to avoid denormals, and for a smoother sound
		inSamples[i] = self.effect.saturator(inSamples[i] -d + d*math.random(), g)
	end
	
	local outSamples = self.effect.downSampler(inSamples, blockSize*4) 
	
	--Normalise, more or less
	local postGain  = 1 / self.effect.preGain 
	
	for i = 0,smax do
		s[i] = outSamples[i] * postGain
	end
end

local function updateFilters(args)
	for _, f in pairs(effects) do
		f:update(args)
	end
end

params = plugin.manageParams {
	-- automatable VST/AU parameters
	-- note the new 1.3 way of declaring them
	{
		name = "PreGain";
		min = -30;
		max = 30;
		default = 0;
		changed = function(val) updateFilters{preGain=math.pow(10,val/20)} end;
	};
	{
		name = "Cutoff";
		min = 0;
		max = 21500;
		default = 11000;
		changed = function(val) updateFilters{cutoff=val} end;
	};
}

-- Reset the plugin parameters like this :
-- params.resetToDefaults()
