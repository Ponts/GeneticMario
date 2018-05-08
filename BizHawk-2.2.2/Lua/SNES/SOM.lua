controller = {}
controller["P1 A"] = false
controller["P1 B"] = false
controller["P1 X"] = false
controller["P1 Up"] = false
controller["P1 Down"] = false
controller["P1 Left"] = false
controller["P1 Right"] = false

Filename = "lvl2.State"
resolution = 16
sightRange = 7
topology = {450,8,8,7}
timeout = 180

function bitwiseand(a,b) 
	local result = 0
	local bitval = 1
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then
			result = result + bitval
		end
		bitval = bitval*2
		a = math.floor(a/2)
		b = math.floor(b/2)
	end
	return result
end

function getInitialPopulation(size)
	population = {}
	for i = 1,size do
		population[i] = dofile "brain.lua"
		population[i].constructor(topology)
	end
	return population
end

function runPopulation(population)
	scores = {}
	for i = 1,#population do
		scores[i], _ = play(population[i])
	end

	--Choose best stuffisisefs TODO
	local bestScore = -math.huge
	local bestIndex = 1
	for i = 1,#population do
		if bestScore < scores[i] then
			bestScore = scores[i]
			bestIndex = i
		end
	end

	return bestIndex
end



function play(brain)
	savestate.load(Filename)
	local prevMarioX = 0
	local totalTime = 0
	local stuckTime = 0
	while true do
		totalTime = totalTime + 1
		marioX, inputs = getInputs()
		if marioX > prevMarioX then
			prevMarioX = marioX
			stuckTime = totalTime
		elseif totalTime - stuckTime > timeout then
			return marioX - (totalTime), totalTime
		end

		--displayInputs(inputs)
		output = brain.think(inputs)
		i = 1
		for key,_ in pairs(controller) do
			controller[key] = output[i] > 0.5
			i = i + 1
		end
		joypad.set(controller)
		emu.frameadvance()
	end
end

function clearController()
	for button, _ in pairs(controller) do
		controller[button] = false
	end
end

function getPositions()
	local marioX = memory.read_s16_le(0x94)
	local marioY = memory.read_s16_le(0x96)
	return marioX, marioY
end

function getTile(marioX, marioY, dx, dy)
	x = math.floor((marioX+dx+8)/16)
	y = math.floor((marioY+dy)/16)
	return memory.readbyte(0x1C800 + math.floor(x/16)*0x1B0 + y*16 + x%16)
end

function getSprites()
	local sprites = {}
	for slot=0,11 do
		local status = memory.readbyte(0x14C8+slot)
		--local enemyStatus = memory.readbyte(0x167A+slot)

		--										 procces info each frame				use default intercation                
		if (status == 8 or status == 0xA) then--and (bitwiseand(enemyStatus,32) == 32 or bitwiseand(enemyStatus,128)==0) then
			local spriteX = memory.readbyte(0x14E0+slot)*256 + memory.readbyte(0xE4+slot)
			local spriteY = memory.readbyte(0x14D4+slot)*256 + memory.readbyte(0xD8+slot)
			sprites[#sprites + 1] = {["x"] = spriteX, ["y"] = spriteY}
		end
	end

	--extended
	for slot = 0,11 do
		local status = memory.readbyte(0x170B+slot)
		if status ~= 0 then
			local spriteX = memory.readbyte(0x1733+slot)*256 + memory.readbyte(0x171F+slot)
			local spriteY = memory.readbyte(0x1729+slot)*256 + memory.readbyte(0x1715+slot)
			sprites[#sprites + 1] = {["x"]=spriteX, ["y"]=spriteY}
		end
	end

	return sprites
end

function getInputs()
	local marioX, marioY = getPositions()
	local sprites = getSprites()
	local inputs = {}


	for dx = -sightRange*resolution, sightRange*resolution, resolution do
		for dy = -sightRange*resolution, sightRange*resolution, resolution do
			inputs[#inputs+1] = 0
			local tile = getTile(marioX, marioY, dx, dy)

			if tile == 1 then
				inputs[#inputs] = 1
			end
		end
	end

	for dx = -sightRange*resolution, sightRange*resolution, resolution do
		for dy = -sightRange*resolution, sightRange*resolution, resolution do
			inputs[#inputs+1]=0

			for i = 1, #sprites do
				xDist = math.abs(sprites[i].x - (marioX+dx))
				yDist = math.abs(sprites[i].y - (marioY+dy))
				if xDist <= 8 and yDist <=8 then
					inputs[#inputs] = 1
				end
			end
		end
	end
	return marioX, inputs
end

function displayInputs(inputs)
	local tiles = {}
	local xPad = 40	
	local yPad = 70
	local tileSize = 4
	local count = 1
	for x = -sightRange, sightRange do
		for y = -sightRange, sightRange do
			tile = {}
			tile.x = xPad+tileSize*x
			tile.y = yPad+tileSize*y
			tile.value = inputs[count]
			tiles[#tiles + 1] = tile
			count=count+1
		end
	end
	for x = -sightRange, sightRange do
		for y = -sightRange, sightRange do
			tile = {}
			tile.x = xPad+tileSize*x
			tile.y = yPad+tileSize*y
			tile.value = -inputs[count]
			tiles[#tiles + 1] = tile
			count=count+1
		end
	end

	gui.drawBox(xPad-sightRange*tileSize-3, yPad-sightRange*tileSize-3, xPad+sightRange*tileSize+2, yPad+sightRange*tileSize+2, 0x00000000, 0x80808080)
	for i, tile in pairs(tiles) do
		if tile.value == 1 then
			gui.drawBox(tile.x -tileSize/2,tile.y-tileSize/2,tile.x+tileSize/2,tile.y+tileSize/2,0x00000000,0xFFFFFFFF)
		elseif tile.value == -1 then
			gui.drawBox(tile.x -tileSize/2,tile.y-tileSize/2,tile.x+tileSize/2,tile.y+tileSize/2,0x00000000,0xFFFF0000)
		end
	end
end

function saveBrain(brain, filename)
	local f = assert(io.open("meta/"..filename, "w"))
	f:write(brain.serialize())
	f:close()
end

function loadBrain(filename)
	local f = assert(io.open("meta/"..filename, "r"))
	serialized = f:read("*all")
	
	local brain = dofile "brain.lua"
	brain.stringConstructor(serialized)
	f:close()
	return brain
end


population = getInitialPopulation(15)
bestI = runPopulation(population)
saveBrain(population[bestI], "test")
brain = {loadBrain("test")}

print("RUNNING BEST NAOOOOOW")
runPopulation(brain)



print("DONE")