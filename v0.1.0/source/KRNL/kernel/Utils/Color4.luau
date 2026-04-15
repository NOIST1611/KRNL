local Color4 = {} :: any
Color4.__index = Color4

export type Color4 = {
	R: number,
	G: number,
	B: number,
	A: number,
	
	FromRGB:  (r: number, g: number, b: number, a: number?) -> Color4,
	FromHEX:  (hex: string) -> Color4,
	FromHSV:  (h: number, s: number, v: number, a: number?) -> Color4,
	FromHSL:  (h: number, s: number, l: number, a: number?) -> Color4,
	FromHWB:  (h: number, w: number, b: number, a: number?) -> Color4,
	
	ToHSV:    (self: Color4) -> (number, number, number),
	ToHSL:    (self: Color4) -> (number, number, number),
	ToHWB:    (self: Color4) -> (number, number, number),
	ToHEX:    (self: Color4, withAlpha: boolean?) -> string,
	
	Lighten:    (self: Color4, amount: number) -> Color4,
	Darken:     (self: Color4, amount: number) -> Color4,
	Saturate:   (self: Color4, amount: number) -> Color4,
	Desaturate: (self: Color4, amount: number) -> Color4,
	Grayscale:  (self: Color4) -> Color4,
	Invert:     (self: Color4) -> Color4,
	RotateHue:  (self: Color4, degrees: number) -> Color4,
	Blend: 		 (self: Color4,blend: Color4,mode: BlendMode,t: number) -> Color4,
	
	Complementary:      (self: Color4) -> Color4,
	Triadic:            (self: Color4) -> (Color4, Color4),
	Analogous:          (self: Color4, angle: number?) -> (Color4, Color4),
	SplitComplementary: (self: Color4) -> (Color4, Color4),
	Tetradic:           (self: Color4) -> (Color4, Color4, Color4),
	
	Lerp: (self: Color4, other: Color4, t: number) -> Color4,
	
	__add:      (Color4, Color4 | number) -> Color4,
	__sub:      (Color4, Color4 | number) -> Color4,
	__mul:      (Color4, Color4 | number) -> Color4,
	__div:      (Color4, Color4 | number) -> Color4,
	__mod:      (Color4, Color4 | number) -> Color4,
	__pow:      (Color4, Color4 | number) -> Color4,
	__unm:      (Color4) -> Color4,
	__eq:       (Color4, Color4) -> boolean,
	__tostring: (Color4) -> string,
	
	Convert: (self: Color4) -> color,
	Clone: (self: Color4) -> Color4,
	
	FlatColor: {[string]: Color4},
}

local BlendMode = {
	Normal      = "Normal",
	Multiply    = "Multiply",
	Screen      = "Screen",
	Overlay     = "Overlay",
	SoftLight   = "SoftLight",
	HardLight   = "HardLight",
	Difference  = "Difference",
	Exclusion   = "Exclusion",
	Darken      = "Darken",
	Lighten     = "Lighten",
}

export type BlendMode = "Normal" | "Multiply" | "Screen" | "Overlay" | "SoftLight" | "HardLight" | "Difference" | "Exclusion" | "Darken" | "Lighten"

local floor = math.floor
local clamp = math.clamp
local max = math.max
local min = math.min
local abs = math.abs
local sqrt = math.sqrt

local function hue2rgb(p, q, t)
	if t < 0 then t = t + 1 end
	if t > 1 then t = t - 1 end
	if t < 1 / 6 then return p + (q - p) * 6 * t end
	if t < 1 / 2 then return q end
	if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
	return p
end

local function unpackOther(other)
	if type(other) == "number" then
		return other, other, other, other
	end
	return other.R, other.G, other.B, other.A
end

local function rgbToHSV(r, g, b)
	local r, g, b = r / 255, g / 255, b / 255
	local cmax = max(r, g, b)
	local cmin = min(r, g, b)
	local delta = cmax - cmin

	local h, s, v
	v = cmax
	s = cmax == 0 and 0 or delta / cmax

	if delta == 0 then
		h = 0
	elseif cmax == r then
		h = 60 * (((g - b) / delta) % 6)
	elseif cmax == g then
		h = 60 * (((b - r) / delta) + 2)
	else
		h = 60 * (((r - g) / delta) + 4)
	end

	return h, s, v
end

local function blendChannel(b, s, mode, t)
	local result

	if mode == BlendMode.Normal then
		result = s

	elseif mode == BlendMode.Multiply then
		result = b * s

	elseif mode == BlendMode.Screen then
		result = 1 - (1 - b) * (1 - s)

	elseif mode == BlendMode.Overlay then
		result = b < 0.5
			and 2 * b * s
			or  1 - 2 * (1 - b) * (1 - s)

	elseif mode == BlendMode.SoftLight then
		if s <= 0.5 then
			result = b - (1 - 2 * s) * b * (1 - b)
		else
			local d = b <= 0.25
				and ((16 * b - 12) * b + 4) * b
				or  sqrt(b)
			result = b + (2 * s - 1) * (d - b)
		end

	elseif mode == BlendMode.HardLight then
		result = s < 0.5
			and 2 * b * s
			or  1 - 2 * (1 - b) * (1 - s)

	elseif mode == BlendMode.Difference then
		result = abs(b - s)

	elseif mode == BlendMode.Exclusion then
		result = b + s - 2 * b * s

	elseif mode == BlendMode.Darken then
		result = min(b, s)

	elseif mode == BlendMode.Lighten then
		result = max(b, s)

	else
		result = s
	end

	return clamp(floor((b * (1 - t) + result * t) * 255), 0, 255)
end

local function rgbToHSL(r, g, b)
	local r, g, b = r / 255, g / 255, b / 255
	local cmax = max(r, g, b)
	local cmin = min(r, g, b)
	local delta = cmax - cmin

	local h, s, l
	l = (cmax + cmin) / 2

	if delta == 0 then
		h = 0
		s = 0
	else
		s = delta / (1 - math.abs(2 * l - 1))
		if cmax == r then
			h = 60 * (((g - b) / delta) % 6)
		elseif cmax == g then
			h = 60 * (((b - r) / delta) + 2)
		else
			h = 60 * (((r - g) / delta) + 4)
		end
	end

	return h, s, l
end

local function fromHSL(h, s, l, a)
	local r, g, b
	if s == 0 then
		r, g, b = l, l, l
	else
		local q = l < 0.5 and l * (1 + s) or l + s - l * s
		local p = 2 * l - q
		local hn = h / 360
		r = hue2rgb(p, q, hn + 1 / 3)
		g = hue2rgb(p, q, hn)
		b = hue2rgb(p, q, hn - 1 / 3)
	end
	local inst = setmetatable({}, Color4)
	inst.R = floor(r * 255)
	inst.G = floor(g * 255)
	inst.B = floor(b * 255)
	inst.A = a or 255
	return inst
end

local function fromHSV(h, s, v, a)
	local i = floor(h / 60) % 6
	local f = (h / 60) - floor(h / 60)
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)

	local r, g, b
	if i == 0 then r, g, b = v, t, p
	elseif i == 1 then r, g, b = q, v, p
	elseif i == 2 then r, g, b = p, v, t
	elseif i == 3 then r, g, b = p, q, v
	elseif i == 4 then r, g, b = t, p, v
	elseif i == 5 then r, g, b = v, p, q
	end

	local inst = setmetatable({}, Color4)
	inst.R = floor(r * 255)
	inst.G = floor(g * 255)
	inst.B = floor(b * 255)
	inst.A = a or 255
	return inst
end

function Color4.FromRGB(r: number, g: number, b: number, a: number?)
	local self = setmetatable({}, Color4)
	self.R = clamp(r or 255,0,255)
	self.G = clamp(g or 255,0,255)
	self.B = clamp(b or 255,0,255)
	self.A = clamp(a or 255,0,255)
	return self
end

function Color4.FromHEX(hex: string)
	local self = setmetatable({}, Color4)
	
	if type(hex) ~= "string" then
		print(string.format("[Color4] Invalid HEX type: expected string, got %s", type(hex)))
		return Color4.FromRGB(0,0,0)
	end

	hex = hex:gsub("#","")

	if not hex:match("^[0-9a-fA-F]+$") then
		print(string.format("[Color4] Invalid HEX characters: %s", hex))
		return Color4.FromRGB(0,0,0)
	end

	if #hex ~= 6 and #hex ~= 8 then
		print(string.format("[Color4] Invalid HEX length (%d): expected 6 or 8", #hex))
		return Color4.FromRGB(0,0,0)
	end
	
	self.R = tonumber(hex:sub(1, 2), 16)
	self.G = tonumber(hex:sub(3, 4), 16)
	self.B = tonumber(hex:sub(5, 6), 16)
	self.A = #hex == 8 and tonumber(hex:sub(7, 8), 16) or 255

	return self
end

function Color4.FromHSV(h: number, s: number, v: number, a: number?)
	return fromHSV(h, s, v, a)
end

function Color4.FromHSL(h: number, s: number, l: number, a: number?)
	return fromHSL(h, s, l, a)
end

function Color4.FromHWB(h: number, w: number, b: number, a: number?)
	local self = setmetatable({}, Color4)

	local total = w + b
	if total > 1 then w = w / total; b = b / total end

	local i = math.floor(h / 60) % 6
	local f = (h / 60) - math.floor(h / 60)
	local sector = {
		{ 1, f, 0 }, { 1 - f, 1, 0 }, { 0, 1, f },
		{ 0, 1 - f, 1 }, { f, 0, 1 }, { 1, 0, 1 - f },
	}

	local rgb = sector[i + 1]
	local scale = 1 - w - b
	self.R = floor((rgb[1] * scale + w) * 255)
	self.G = floor((rgb[2] * scale + w) * 255)
	self.B = floor((rgb[3] * scale + w) * 255)
	self.A = a or 255
	return self
end

function Color4:ToHSV()
	return rgbToHSV(self.R, self.G, self.B)
end

function Color4:ToHSL()
	return rgbToHSL(self.R, self.G, self.B)
end

function Color4:ToHWB()
	local h, s, v = rgbToHSV(self.R, self.G, self.B)
	return h, (1 - s) * v, 1 - v
end

function Color4:ToHEX(withAlpha: boolean?)
	local hex = string.format("%02X%02X%02X", self.R, self.G, self.B)
	if withAlpha then
		hex = hex .. string.format("%02X", self.A)
	end
	return "#" .. hex
end

function Color4:Lighten(amount: number)
	local h, s, l = rgbToHSL(self.R, self.G, self.B)
	return fromHSL(h, s, clamp(l + amount, 0, 1), self.A)
end

function Color4:Darken(amount: number)
	local h, s, l = rgbToHSL(self.R, self.G, self.B)
	return fromHSL(h, s, clamp(l - amount, 0, 1), self.A)
end

function Color4:Saturate(amount: number)
	local h, s, l = rgbToHSL(self.R, self.G, self.B)
	return fromHSL(h, clamp(s + amount, 0, 1), l, self.A)
end

function Color4:Desaturate(amount: number)
	local h, s, l = rgbToHSL(self.R, self.G, self.B)
	return fromHSL(h, clamp(s - amount, 0, 1), l, self.A)
end

function Color4:Grayscale()
	local avg = floor(self.R * 0.299 + self.G * 0.587 + self.B * 0.114)
	return Color4.FromRGB(avg, avg, avg, self.A)
end

function Color4:Invert()
	return Color4.FromRGB(255 - self.R, 255 - self.G, 255 - self.B, self.A)
end

function Color4:RotateHue(degrees: number)
	local h, s, v = rgbToHSV(self.R, self.G, self.B)
	return fromHSV((h + degrees) % 360, s, v, self.A)
end

function Color4:Complementary()
	local h, s, v = rgbToHSV(self.R, self.G, self.B)
	return fromHSV((h + 180) % 360, s, v, self.A)
end

function Color4:Triadic()
	local h, s, v = rgbToHSV(self.R, self.G, self.B)
	return
		fromHSV((h + 120) % 360, s, v, self.A),
		fromHSV((h + 240) % 360, s, v, self.A)
end

function Color4:Analogous(angle: number?)
	local offset = angle or 30
	local h, s, v = rgbToHSV(self.R, self.G, self.B)
	return
		fromHSV((h + offset) % 360, s, v, self.A),
		fromHSV((h - offset + 360) % 360, s, v, self.A)
end

function Color4:SplitComplementary()
	local h, s, v = rgbToHSV(self.R, self.G, self.B)
	return
		fromHSV((h + 150) % 360, s, v, self.A),
		fromHSV((h + 210) % 360, s, v, self.A)
end

function Color4:Tetradic()
	local h, s, v = rgbToHSV(self.R, self.G, self.B)
	return
		fromHSV((h + 90)  % 360, s, v, self.A),
		fromHSV((h + 180) % 360, s, v, self.A),
		fromHSV((h + 270) % 360, s, v, self.A)
end

function Color4.Lerp(self, other, t: number)
	local result = setmetatable({}, Color4)
	t = clamp(t, 0, 1)
	result.R = floor(self.R + (other.R - self.R) * t)
	result.G = floor(self.G + (other.G - self.G) * t)
	result.B = floor(self.B + (other.B - self.B) * t)
	result.A = floor(self.A + (other.A - self.A) * t)
	return result
end

function Color4.Blend(base, blend, mode: string?, t: number?)
	local m = mode or BlendMode.Normal
	local t = clamp(t or 1, 0, 1)

	return Color4.FromRGB(
		blendChannel(base.R / 255, blend.R / 255, m, t),
		blendChannel(base.G / 255, blend.G / 255, m, t),
		blendChannel(base.B / 255, blend.B / 255, m, t),
		base.A
	)
end

function Color4.__add(a, b)
	local r, g, bv, av = unpackOther(b)
	return Color4.FromRGB(
		clamp(a.R + r,  0, 255),
		clamp(a.G + g,  0, 255),
		clamp(a.B + bv, 0, 255),
		clamp(a.A + av, 0, 255)
	)
end

function Color4.__sub(a, b)
	local r, g, bv, av = unpackOther(b)
	return Color4.FromRGB(
		clamp(a.R - r,  0, 255),
		clamp(a.G - g,  0, 255),
		clamp(a.B - bv, 0, 255),
		clamp(a.A - av, 0, 255)
	)
end

function Color4.__mul(a, b)
	if type(a) == "number" then
		return Color4.FromRGB(
			clamp(floor(b.R * a), 0, 255),
			clamp(floor(b.G * a), 0, 255),
			clamp(floor(b.B * a), 0, 255),
			clamp(floor(b.A * a), 0, 255)
		)
	end
	local r, g, bv, av = unpackOther(b)
	return Color4.FromRGB(
		clamp(floor(a.R * r / 255), 0, 255),
		clamp(floor(a.G * g / 255), 0, 255),
		clamp(floor(a.B * bv / 255), 0, 255),
		clamp(floor(a.A * av / 255), 0, 255)
	)
end

function Color4.__div(a, b)
	if type(b) == "number" then
		return Color4.FromRGB(
			clamp(floor(a.R / b), 0, 255),
			clamp(floor(a.G / b), 0, 255),
			clamp(floor(a.B / b), 0, 255),
			clamp(floor(a.A / b), 0, 255)
		)
	end
	return Color4.FromRGB(
		b.R ~= 0 and clamp(floor(a.R / b.R * 255), 0, 255) or 0,
		b.G ~= 0 and clamp(floor(a.G / b.G * 255), 0, 255) or 0,
		b.B ~= 0 and clamp(floor(a.B / b.B * 255), 0, 255) or 0,
		b.A ~= 0 and clamp(floor(a.A / b.A * 255), 0, 255) or 0
	)
end

function Color4.__mod(a, b)
	local r, g, bv, av = unpackOther(b)
	return Color4.FromRGB(
		a.R % r,
		a.G % g,
		a.B % bv,
		a.A % av
	)
end

function Color4.__pow(a, b)
	local r, g, bv, av = unpackOther(b)
	return Color4.FromRGB(
		clamp(floor(a.R ^ r), 0, 255),
		clamp(floor(a.G ^ g), 0, 255),
		clamp(floor(a.B ^ bv), 0, 255),
		clamp(floor(a.A ^ av), 0, 255)
	)
end

function Color4.__unm(a)
	return Color4.FromRGB(255 - a.R, 255 - a.G, 255 - a.B, a.A)
end

function Color4.__eq(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B and a.A == b.A
end

function Color4:__tostring()
	return string.format("Color4(%d, %d, %d, %d)", self.R, self.G, self.B, self.A)
end

function Color4:Convert()
	return ColorRGBA(self.R, self.G, self.B, self.A)
end

function Color4:Clone()
		local clone = setmetatable({},Color4)
		
		clone.R = self.R
		clone.G = self.G
		clone.B = self.B
		clone.A = self.A
		
		return clone
end

local FlatColors = {
	["White"] = Color4.FromRGB(255,255,255),
	["Black"] = Color4.FromRGB(0,0,0),
	["Gray"] = Color4.FromRGB(128,128,128),
	["Light Gray"] = Color4.FromRGB(200,200,200),
	["Dark Gray"] = Color4.FromRGB(64,64,64),

	["Red"] = Color4.FromRGB(255,0,0),
	["Green"] = Color4.FromRGB(0,255,0),
	["Blue"] = Color4.FromRGB(0,0,255),

	["Yellow"] = Color4.FromRGB(255,255,0),
	["Orange"] = Color4.FromRGB(255,165,0),
	["Purple"] = Color4.FromRGB(128,0,128),
	["Pink"] = Color4.FromRGB(255,192,203),

	["Cyan"] = Color4.FromRGB(0,255,255),
	["Magenta"] = Color4.FromRGB(255,0,255),
	["Lime"] = Color4.FromRGB(50,205,50),
	["Teal"] = Color4.FromRGB(0,128,128),

	["Brown"] = Color4.FromRGB(139,69,19),
	["Olive"] = Color4.FromRGB(128,128,0),
	["Navy"] = Color4.FromRGB(0,0,128),
	
	["Bright red"] = Color4.FromRGB(196,40,28),
	["Medium red"] = Color4.FromRGB(218,134,122),
	["Bright blue"] = Color4.FromRGB(13,105,172),
	["Bright yellow"] = Color4.FromRGB(245,205,48),
	["Bright green"] = Color4.FromRGB(75,151,75),

	["Institutional white"] = Color4.FromRGB(248,248,248),
	["Really black"] = Color4.FromRGB(17,17,17),
	["Really red"] = Color4.FromRGB(255,0,0),
	["Really blue"] = Color4.FromRGB(0,0,255),

	["Lime green"] = Color4.FromRGB(0,255,0),
	["Lavender"] = Color4.FromRGB(140,91,159),
	["Hot pink"] = Color4.FromRGB(255,0,191),

	["Pastel yellow"] = Color4.FromRGB(255,255,204),
	["Pastel orange"] = Color4.FromRGB(255,204,153),
	["Pastel violet"] = Color4.FromRGB(204,153,255),

	["Royal purple"] = Color4.FromRGB(98,37,209),
	["Navy blue"] = Color4.FromRGB(0,32,96),

	["Bright orange"] = Color4.FromRGB(218,133,65),
	["Bright violet"] = Color4.FromRGB(107,50,124),
	["Bright bluish green"] = Color4.FromRGB(0,143,156),
	["Bright yellowish green"] = Color4.FromRGB(164,189,71),
	["Bright yellowish orange"] = Color4.FromRGB(226,155,64),

	["Neon orange"] = Color4.FromRGB(213,115,61)
}

Color4.FlatColor = setmetatable({}, {
	__index = function(_, name: string)
		local preset = FlatColors[name]
		if not preset then
			print(string.format("[Color4.FlatColor] Unknown color: '%s'", name))
			return Color4.FromRGB(0, 0, 0)
		end
		return preset:Clone()
	end,
	__newindex = function()
		print("[Color4.FlatColor] FlatColor is read-only")
	end,
}) 

return Color4 :: Color4
