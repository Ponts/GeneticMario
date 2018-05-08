local this = {}


function this.constructor(topology)
	this.topology = topology

	--create matrixes
	this.W = {}
	this.b = {}
	for layer=1,#topology-1 do
		this.b[layer] = {}
		this.W[layer] = {}
		for i = 1,topology[layer+1] do
			this.W[layer][i] = {}
			this.b[layer][i] = gaussian(0,2/topology[layer])
			for j = 1,topology[layer] do
				this.W[layer][i][j] = gaussian(0,2/(topology[layer])) 
			end
		end
	end
end

function this.stringConstructor(str)
	local rows = {}
	this.topology = {}
	this.W = {}
	this.b = {}
	for row in str:gmatch("[^\\\n]+") do 
		rows[#rows+1] = row
	end
	for layer in rows[1]:gmatch("%S+") do
		this.topology[#this.topology+1] = tonumber(layer)
	end
	local rowIndex = 2
	for layer = 1,#this.topology-1 do
		this.W[layer] = {}
		this.b[layer] = {}
		local rowsToIterate = this.topology[layer+1]
		for i = 1,rowsToIterate do
			this.W[layer][i] = {}
			for weight in rows[i+rowIndex-1]:gmatch("%S+") do
				this.W[layer][i][#this.W[layer][i]+1] = tonumber(weight)
			end
		end
		rowIndex = rowIndex + rowsToIterate
		for weight in rows[rowIndex]:gmatch("%S+") do
			this.b[layer][#this.b[layer]+1] = tonumber(weight)
		end
		rowIndex = rowIndex + 1
	end

	
end

function this.think(input)
	h = input
	for layer=1,#this.W do
		h = this.add(this.dot(this.W[layer],h),this.b[layer])
		h = this.sigmoid(h)
	end
	return h
end

function this.sigmoid(h)
	for i = 1,#h do
		h[i] = 1/(1 + math.exp(-4.9*h[i]))
	end
	return h
end

function this.dot(A,B)
	local C = {}
	for i=1,#A do
		C[i] = 0
		for k =1,#B do
			C[i] = C[i] + A[i][k] * B[k]
		end
	end
	return C
end

function this.add(A,B)
	C = {}
	for i = 1,#A do
		C[i] = A[i] + B[i]
	end
	return C
end

function gaussian (mean, variance)
    return  math.sqrt(-2 * variance * math.log(math.random())) *
            math.cos(2 * math.pi * math.random()) + mean
end

function this.serialize()
	local string = ""
	for i=1,#this.topology do
		string = string..this.topology[i] .. " "
	end
	string = string.."\n"

	for layer = 1,#this.W do
		for i = 1,#this.W[layer] do
			for j = 1,#this.W[layer][i] do
				string = string..this.W[layer][i][j] .. " "
			end
			string = string.."\n"
		end
		for i = 1,#this.b[layer] do
			string = string..this.b[layer][i] .." "
		end
		string = string.."\n"
	end
	return string
end

function this.deserialize(str)
	
end



return this