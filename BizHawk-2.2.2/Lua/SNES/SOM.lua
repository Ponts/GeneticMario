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
sightRange = 6
topology = {338,32,16,7}
timeout = 180

function getInitialPopulation(size)
	population = {}
	for i = 1,size do
		population[i] = dofile "brain.lua"
		population[i].constructor(topology)
	end
	return population
end

function runPopulation(population, generationId,championScore)
	local scores = {}
	scores[1] = championScore
	for i = 2,#population do
		scores[i] = play(population[i], generationId, i)
		while forms.ischecked(FORMrunBestBox) do
			play(population[1], "Best", "Best")
		end
		if forms.ischecked(FORMrunChampsBox) then
			playChampions()
		end
	end
	--Choose best stuffisisefs TODO
	local bestScore = -100.0
	local bestIndex = 1
	for i = 1,#population do
		if bestScore < scores[i] then
			bestScore = scores[i]
			bestIndex = i
		end
	end
	if scores[1] < bestScore then
		setSaveThisGen()
	end
	forms.settext(FORMfitnessLabel,"Best fitness: "..math.floor(bestScore))
	return scores, bestIndex
end

function getNewPopulation(population, scores, bestIndex)
	local newPopulation = {}
	local P = softmax(scores)
	newPopulation[#newPopulation+1] = population[bestIndex].copy()
	while #newPopulation < #population do
		local male = getRandomBrain(population, P)
		local female = getRandomBrain(population, P)
		local child = male.mate(female)
		child.mutate()
		newPopulation[#newPopulation+1] = child

	end
	return newPopulation
end

function getRandomBrain(population, P)
	local value = math.random()
	local border = 0
	for i = 1,#P do
		border = border + P[i]
		if value < border then
			return population[i]
		end
	end
	return population[#population]
end

function softmax(x)
	local min = math.min(unpack(x))
	for i = 1,#x do
		x[i] = x[i] - min
	end
	local sum = 0.0
	for i = 1,#x do
		sum = sum + x[i]
	end
	local P = {}
	for i = 1, #x do
		P[i] = x[i]/sum
	end
	return P
end



function calculateFitness(pos, time)
	return pos - (0.1*time)
end

function play(brain, generationId, populationId)
	savestate.load(Filename)
	local prevMarioX = 0
	local totalTime = 0
	local stuckTime = 0
	clearController()
	while true do
		totalTime = totalTime + 1
		marioX, inputs = getInputs()
		if marioX > prevMarioX then
			prevMarioX = marioX
			stuckTime = totalTime
		elseif totalTime - stuckTime > timeout then
			return calculateFitness(marioX, totalTime)
		end
		if forms.ischecked(FORMCurrData) then 
			displayInfo(generationId, populationId, calculateFitness(marioX, totalTime), inputs)
		end
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
	joypad.set(controller)
end

function getPositions()
	local marioX = memory.read_s16_le(0x94)
	local marioY = memory.read_s16_le(0x96)
	return marioX, marioY
end

function getTile(marioX, marioY, dx, dy)
	local x = math.floor((marioX+dx+8)/16)
	local y = math.floor((marioY+dy)/16)
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
				local xDist = math.abs(sprites[i].x - (marioX+dx))
				local yDist = math.abs(sprites[i].y - (marioY+dy))
				if xDist <= 8 and yDist <=8 then
					inputs[#inputs] = 1
				end
			end
		end
	end
	return marioX, inputs
end

function displayInfo(generationId, populationId, fitness, inputs, showInputArea)
	if forms.ischecked(FORMShowInput) then 
		local tiles = {}
		local xPad = 220
		local yPad = 35
		local tileSize = 4
		local count = 1
		for x = -sightRange, sightRange do
			for y = -sightRange, sightRange do
				local tile = {}
				tile.x = xPad+tileSize*x
				tile.y = yPad+tileSize*y
				tile.value = inputs[count]
				tiles[#tiles + 1] = tile
				count=count+1
			end
		end
		for x = -sightRange, sightRange do
			for y = -sightRange, sightRange do
				local tile = {}
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

	gui.drawText(0,10,"Generation: "..generationId.."\nPopulation: "..populationId.."\nFitness: "..math.floor(fitness), _, 0xA0808080, 12)

end

function saveGeneration(population, generationId)
	local saveString = ""
	for i = 1, #population do
		saveString = saveString .. "<brain>\n"
		saveString = saveString .. population[i].serialize()
		saveString = saveString .. "</brain>\n"
	end
	local f = assert(io.open("meta/backup", "wb+"))
	f:write(saveString)
	f:close()
	local f = assert(io.open("meta/generationID", "wb+"))
	f:write("Generation backuped at: "..generationId)
	f:close()
end

function saveMeta(generationId, scores, bestId, startTime)
	local meanScore = 0.0
	for i = 1,#scores do
		meanScore = meanScore + scores[i]
	end
	meanScore = meanScore/#scores
	local variance = 0.0
	for i = 1,#scores do
		variance = math.pow(scores[i] - meanScore,2)
	end
	variance = variance/#scores
	timeSinceStart = os.clock() - startTime
	local f = assert(io.open("meta/metaData", "a"))
	f:write(generationId .. " " .. scores[bestId] .. " " .. meanScore .. " " .. variance .." "..timeSinceStart.. "\n")
	f:close()
end


function loadGeneration()
	local f = assert(io.open("meta/backup", "rb"))
	local str = f:read("*all")
	local pop = {}
	local brainString = ""
	for line in str:gmatch("[^\\\n]+") do
		if line == "<brain>" then
			brainString = ""
		elseif line == "</brain>" then
			local brain = dofile "brain.lua"
			brain.stringConstructor(brainString)
			pop[#pop+1] = brain
		else
			brainString = brainString .. line .. "\n"
		end
	end
	f:close()
	return pop
end

function playChampions()
	local champs, gens = loadChampions()
	while forms.ischecked(FORMrunChampsBox) do
		for i = 1,#champs do
			play(champs[i], gens[i], "Best")
		end
	end
end

function saveChamp(brain, generationId)
	local f = assert(io.open("meta/champions", "ab"))
	f:write("<brain>\n")
	f:write(generationId.."\n")
	f:write(brain.serialize())
	f:write("</brain>\n")
	f:close()
end

function loadChampions()
	local f = assert(io.open("meta/champions", "rb"))
	local str = f:read("*all")
	local pop = {}
	local brainString = ""
	local generationTime = false
	local genIds = {}
	for line in str:gmatch("[^\\\n]+") do
		if generationTime then
			genIds[#genIds+1] = tonumber(line)
			generationTime = false
		elseif line == "<brain>" then
			generationTime = true
			brainString = ""
		elseif line == "</brain>" then
			local brain = dofile "brain.lua"
			brain.stringConstructor(brainString)
			pop[#pop+1] = brain
		else
			brainString = brainString .. line .. "\n"
		end
	end
	f:close()
	return pop, genIds
end

function generateForm()
	local myForm = forms.newform(200, 340, "Run best")
	forms.setlocation(myForm, 206, 3)
	FORMfitnessLabel = forms.label(myForm, "Best fitness: "..0, 5, 5)
	FORMrunBestBox = forms.checkbox(myForm, "Run Champ!",5,30)
	FORMsaveThis = forms.button(myForm, "Save", setSaveThisGen,5, 55)
	FORMlastSavedGen = forms.label(myForm, "Last saved gen: "..0 ,5,80)
	FORMrunChampsBox = forms.checkbox(myForm, "Run Champs!",5,105)
	FORMmapSelect = forms.textbox(myForm, Filename,_,_,_,5,130)
	FORMgenSelect = forms.textbox(myForm, 0,_,_,_,5,155)
	FORMstartButton = forms.button(myForm, "Start", startPlay, 5,180)
	FORMendButton = forms.button(myForm, "Stop", stop, 5, 205)
	FORMShowInput = forms.checkbox(myForm, "Show Input",5,230)
	FORMCurrData = forms.checkbox(myForm, "Show Current Data",5,256)
	event.onexit(destroyForm)

end

saveThisGen = false
function setSaveThisGen()
	saveThisGen = true
end

keepPlaying = true
function stop()
	keepPlaying = false
	startPlaying = false
end

function destroyForm()
	forms.destroyall()
end

startPlaying = false
function startPlay()
	startPlaying = true
end


function main()
	keepPlaying = true
	local generation = tonumber(forms.gettext(FORMgenSelect))
	Filename = forms.gettext(FORMmapSelect)
	local population = {}
	local championScore = -100.0
	local notLoaded = true
	local startTime = os.clock()
	if generation == 0 then
		population = getInitialPopulation(10)
		generation = 1
	else
		population = loadGeneration()
		championScore = play(population[1],generation,1)
		notLoaded = false
	end
	while keepPlaying do
		local scores, bestI = runPopulation(population, generation, championScore)
		championScore = scores[bestI]
		if saveThisGen and notLoaded then
			saveGeneration(population, generation)
			forms.settext(FORMlastSavedGen, "Last saved gen: "..generation)
			saveChamp(population[bestI],generation)
			saveThisGen = false
		end
		if notLoaded then 
			saveMeta(generation, scores, bestI, startTime)
		end
		notLoaded = true
		population = getNewPopulation(population, scores, bestI)
		generation = generation + 1
	end
end

generateForm()

while true do
	if startPlaying then
		main()
	else
		emu.frameadvance()
	end
end



print("DONE")