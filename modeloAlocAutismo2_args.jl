using JuMP
#using Cbc
using CPLEX
#using Gurobi
using XLSX
using Conda
Conda.add("openpyxl")
using PyCall
xl = pyimport("openpyxl")

function runall()
	
#	solve("../0.instancias/instancia-v6.3-julia-modifRK.xlsx", "instancia-real-TO_DO_3_3dias", 3600)
#	solve("../0.instancias/instancia-v6.3-julia-modifRK.xlsx", "instancia-real-TO_DO_3_4dias", 3600)
#	solve("../0.instancias/instancia-v6.3-julia-modifRK.xlsx", "instancia-real-TO_DO_3_5dias", 3600)
#	solve("../0.instancias/instancia-v6.3-julia-modifRK.xlsx", "instancia-real-TO_DO_3_10dias", 3600)
#	solve("../0.instancias/instancia-v6.3-julia-modifRK.xlsx", "instancia-real-TO_DO_3_20dias", 3600)
	
	solve("../0.instancias/instancia-v7-julia-modifRK.xlsx", "instancia-real-TO_DO_3_3dias", 3600)
	solve("../0.instancias/instancia-v7-julia-modifRK.xlsx", "instancia-real-TO_DO_3_4dias", 3600)
	solve("../0.instancias/instancia-v7-julia-modifRK.xlsx", "instancia-real-TO_DO_3_5dias", 3600)
	solve("../0.instancias/instancia-v7-julia-modifRK.xlsx", "instancia-real-TO_DO_3_10dias", 3600)
	solve("../0.instancias/instancia-v7-julia-modifRK.xlsx", "instancia-real-TO_DO_3_20dias", 3600)
	
end

function solve(instance_excel, sheetname, timelimit)

	#Lendo os dados da instância (arquivo excel) -------------------------------------------
	println("reading data...")
	
	excelfile = XLSX.readxlsx(instance_excel)
	data = excelfile[sheetname]

	nrC = data[1,2] #nr de clientes XLSX.readdata(instance_excel,sheetname,"B1")
	nrT = data[2,2]  #nr de terapias
	nrProfPerTherapy = min(nrC,15)
	nrProfessionals = nrProfPerTherapy*nrT #no pior caso todos clientes demandarão todo tipo de terapia e cada um deles ficará com um profissional diferente naquela terapia
	nrRooms = data[3,2]  #nr de salas
	nrDays = data[4,2]  #nr de dias
#	nrH = 8  #nr de horários
	nrSlots = sum(data[5,j] for j in 2:(nrDays+1))
	nrShifts = sum(data[6,j] for j in 2:(nrDays+1))
	CapacShiftsPerProf = data[7,2]
	CapacShiftsPerClient = data[8,2]
	TherapyCosts = data[9,2:(nrT+1)]
	NomeSala = data[10,2:(nrT+1)]
	
	println("CapC=", CapacShiftsPerClient, ", CapP=", CapacShiftsPerProf)
	
	demands = []
	for i in 1:nrC
		dem_i = [(t, data[12+i,t+1]) for t in 1:nrT if data[12+i,t+1] > 0]
#		println(dem_i)
		push!(demands, dem_i)
	end

	setProfessionals = [i for i in 1:nrProfessionals]

	#preenchendo a lista de profissionais por terapia
	professionalsTherapy = [] #lista de profissionais por terapia
	for p in 1:nrT
		professionals = [i for i in ((p-1)*nrProfPerTherapy+1):(p*nrProfPerTherapy)]
		push!(professionalsTherapy, professionals) #lista de profissionais por terapia
	end
	
	#preenchendo os custos de cada profissional
	profCosts = []
	for p in 1:nrT
		for i in 1:nrProfPerTherapy
			push!(profCosts, TherapyCosts[p])
		end
	end 
	
	#Definindo as salas por tipo de terapia
	refrow = 12+nrC+2
	therapyRoom = data[(refrow+1):(refrow+nrRooms), 2] #terapia por sala
	roomsTherapy = [] #lista de salas por terapia
	for t in 1:nrT
		vectemp = [r for r in 1:nrRooms if therapyRoom[r] == t]
		push!(roomsTherapy, vectemp)
	end
	
	setSlots = [i for i in 1:nrSlots]
	setShifts = [i for i in 1:nrShifts]
	setDays = [i for i in 1: nrDays]
	setRooms = [i for i in 1: nrRooms]
	
	shiftsDay = [] #lista de turnos por dia
	slotsDay = []  #lista de slots/horários por dia
	slotsShift = [] #lista de slots/horários por turno

	#preenchendo as listas de turnos por dia e slots/horários por dia
	for d in 1:nrDays
		first_slot = first_shift = -1
		if d == 1
			first_slot = first_shift = 1
		else
			first_shift = shiftsDay[d-1][length(shiftsDay[d-1])] + 1
			first_slot = slotsDay[d-1][length(slotsDay[d-1])] + 1
		end
		last_shift = sum(data[6,1+day] for day in 1:d)
		last_slot = sum(data[5,1+day] for day in 1:d)
		
		shifts = [s for s in first_shift:last_shift]
		slots = [s for s in first_slot:last_slot]
		push!(shiftsDay, shifts) #lista de turnos por dia
		push!(slotsDay, slots)   #lista de slots/horários por dia
	end
	
	#preenchendo a lista de slots/horários por turno
	for d in 1:nrDays
		nrslots_d = data[5,1+d]
		nrshifts_d = data[6,1+d]
		
		first_slot_inday_d = -1
		if d == 1
			first_slot_inday_d = 1
		else
			first_slot_inday_d = sum(data[5,1+day-1] for day in 2:d) + 1
		end
		
		last_slot_inday_d = first_slot_inday_d + nrslots_d - 1
		
		currentslot = first_slot_inday_d
		for i in 1:nrshifts_d
			lastslot2 = currentslot+Int64(nrslots_d/nrshifts_d)-1
			slots = [i for i in currentslot:lastslot2]
			push!(slotsShift, slots)  #lista de slots/horários por turno
			currentslot = slots[length(slots)] + 1
		end
	end
	
#	println(demands)
#	println(shiftsDay)
#	println(slotsDay)
#	println(slotsShift)
#	println(professionalsTherapy)
	
#	stdin(Char)
	
	#---------------------------------------------------------------------------------------
	
	#Construindo o modelo matemático -------------------------------------------------------
	println("building mathematical model...")
	
	init_time = time_ns()

#	model = Model(Cbc.Optimizer)
	#set_optimizer_attribute(model, "LogLevel", 0)
#	set_optimizer_attribute(model, "TimeLimit", timelimit)
	model = Model(CPLEX.Optimizer)
	set_optimizer_attribute(model, "CPX_PARAM_TILIM", timelimit)
	
#	model = Model(Gurobi.Optimizer)
#	set_optimizer_attribute(model, "TimeLimit", timelimit)
#	set_optimizer_attribute(model, "Method", 0)
##	set_optimizer_attribute(model, "OutputFlag", 0)
##	set_optimizer_attribute(model, "Presolve", 0)
#	set_optimizer_attribute(model, "IntFeasTol", 1e-6)
#	set_optimizer_attribute(model, "LogFile", "logGUROBI-"*sheetname*".txt")

#	#Definindo as Variáveis de Decisão -----------------------------------------------------
	@variable(model, y[p in 1:nrProfessionals], Bin)
	@variable(model, x[i in 1:nrC, p in 1:nrProfessionals], Bin)
	@variable(model, u[i in 1:nrC, r in 1:nrRooms, s in 1:nrSlots], Bin)
	@variable(model, v[i in 1:nrProfessionals, r in 1:nrRooms, s in 1:nrSlots], Bin)
	@variable(model, z[p in 1:nrProfessionals, k in 1:nrShifts], Bin)
	@variable(model, w[p in 1:nrC, k in 1:nrShifts], Bin)
	
#	#---------------------------------------------------------------------------------------

	#Funcao Objetivo
	@objective(model, Min, sum( profCosts[p] * y[p] for p in setProfessionals ))

	#Restricao 1 
	for i in 1:nrC
		for (t,q) in demands[i]
			@constraint(model, sum(x[i,p] for p in professionalsTherapy[t]) == 1 )
		end
	end
#	print(model)

	#Restricao 2
	for i in 1:nrC
		for p in 1:nrProfessionals
			@constraint(model, x[i,p] <= y[p])
		end
	end

	#Restricao 3
	for i in 1:nrC
		for (t,q) in demands[i]
			for p in professionalsTherapy[t]
				for r in roomsTherapy[t]
					for s in setSlots
						@constraint(model, u[i,r,s] - v[p,r,s] <= 1-x[i,p])
					end
				end
			end
		end
	end
	
	#Restricao 4
	for i in 1:nrC
		for (t,q) in demands[i]
			@constraint(model, sum(u[i,r,s] for r in roomsTherapy[t] for s in setSlots) == q)
#			println(sum(u[i,r,s] for r in roomsTherapy[t] for s in setSlots) , " == ", q)
		end
	end
	
	#Restricao 5
	for s in setSlots
		for r in setRooms
			@constraint(model, sum(u[i,r,s] for i in 1:nrC) <= 1)
		end
	end
	
	#Restricao 6
	for s in setSlots
		for r in setRooms
			@constraint(model, sum(v[p,r,s] for p in 1:nrProfessionals) <= 1)
		end
	end
	
	#Restricao 7
	for t in 1:nrT
		for p in professionalsTherapy[t]
			for r in setdiff(setRooms,roomsTherapy[t])
				@constraint(model, sum(v[p,r,s] for s in setSlots) == 0 )
			end
		end
	end
	
	#Restricao 8a
	for p in 1:nrProfessionals
		@constraint(model, sum(z[p,k] for k in setShifts) <= CapacShiftsPerProf)
	end
	
	#Restricao 8b TODO Links setShifts com as variaveis de alocacao de sala por slots
	for p in 1:nrProfessionals
		for r in setRooms
			for k in setShifts
				for s in slotsShift[k]
					@constraint(model, v[p,r,s] <= z[p,k])
				end
			end
		end
	end
	
	#Restricao 8a.2
	for i in 1:nrC
		@constraint(model, sum(w[i,k] for k in setShifts) <= CapacShiftsPerClient)
	end
	
	#Restricao 8b.2 TODO Links setShifts com as variaveis de alocacao de sala por slots
	for i in 1:nrC
		for r in setRooms
			for k in setShifts
				for s in slotsShift[k]
					@constraint(model, u[i,r,s] <= w[i,k])
				end
			end
		end
	end
	
	#Restricao 9
	for p in 1:nrProfessionals
		for s in setSlots
			@constraint(model, sum(v[p,r,s] for r in setRooms) <= y[p])
		end
	end
	
	#Restricao 10
	for i in 1:nrC
		for s in setSlots
			@constraint(model, sum(u[i,r,s] for r in setRooms) <= 1)
		end
	end
	
	#---------------------------------------------------------------------------------------
	println("solving mathematical model...")
	
#	println(model)
	optimize!(model)
    status = termination_status(model)
    println("STATUS: ", status, " -----------------")
    
    if status == MOI.INFEASIBLE_OR_UNBOUNDED
		println("INVIAVELLLLLLLLLLLLLL")
		compute_conflict!(model)
		
    	list_of_conflicting_constraints = ConstraintRef[]
		for (F, S) in list_of_constraint_types(model)
			for con in all_constraints(model, F, S)
				if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
					push!(list_of_conflicting_constraints, con)
				end
			end
		end
#    	print(list_of_conflicting_constraints)
    	#Irreducible Inconsistent Subsystem (IIS)
		open("IIS-IrreducibleInconsistentSubsystem.txt","a") do io
		   println(io,list_of_conflicting_constraints)
		end
    	
#		if get_attribute(model, MOI.ConflictStatus()) == MOI.CONFLICT_FOUND
#			println("IFFFFF")
#			iis_model, _ = copy_conflict(model)
#			print(iis_model)
#		else
#			println("ELSEEEEEEEE")
#		end
		return
	end

#	if status == MOI.INFEASIBLE_OR_UNBOUNDED
#		println("INVIAVELLLLLLLLLLLLLL")
#		@assert termination_status(model) == MOI.INFEASIBLE_OR_UNBOUNDED
#		compute_conflict!(model)
#		MOI.get(model, MOI.ConstraintConflictStatus(), const1) 
#	end
    
    print("\nHired Professionals: ")
    sumcost = 0
    for p in 1:nrProfessionals
    	if value(y[p]) > 0.9999
    		print(p, " (cost=", profCosts[p],"), ")
    		sumcost += profCosts[p]
    	end
    end
    println("\nTotal Cost = ", sumcost)
    
    for d in setDays
    	println("\nAllocations in Day ", d, " =============================================")
		println("Clients allocation (i,r,s) -----------------------")
		for i in 1:nrC
			for r in setRooms
				for s in slotsDay[d]
					if value(u[i,r,s]) > 0.9999
						println(i, " ", r, " ", s)
					end
				end
			end
		end
		
		println("Professionals allocation (p,r,s) -----------------")
		for p in 1:nrProfessionals
			for r in setRooms
				for s in slotsDay[d]
					if value(v[p,r,s]) > 0.9999
						println(p, " ", r, " ", s)
					end
				end
			end
		end
    end
    
#	XLSX.openxlsx("instanciasProjAutismo/instProjAutismo.xlsx", mode="rw") do xf
#		sheet = xf["solution"]
#		println("KKKKKKKKKKKKKKKK ", sheet)
#		sheet[2, 8] = "add new line"
#	end
	
    
    #writing solution into excel file
	maxSlotsInADay = maximum([length(slotsDay[d]) for d in setDays])
	println("Max nb. of slots in a day: ", maxSlotsInADay)
	xf = XLSX.openxlsx(instance_excel, mode="rw") do xf
		sheetname = "solution"
		sh = xf[sheetname]#sheetname]
	
		#Limpando os conteúdos das células antes de preenche-las
#		for d in setDays
#			rowref = 3*d
#			for r in setRooms
#			
#				row = rowref
#				column = 1+r
#				sh[row, column] = string("")
#				
#				for s in slotsDay[d]
#					row = rowref+s
#					column = 1+r
#					sh[row, column] = string("")
#				end
#			end
#		end
		for row in 1:300
			for column in 1:100
				sh[row, column] = string("")
			end
		end
		
		for d in setDays
#	    	println("\nAllocations in Day ", d, " =============================================")
#			println("Clients allocation (i,r,s) -----------------------")

			rowref = 3*d
			
			for r in eachindex(therapyRoom)
				sh[rowref+maxSlotsInADay*(d-1), r+1] = NomeSala[therapyRoom[r]]
			end
			
			println("Slots day ", d, ": ", slotsDay[d])
			for i in 1:nrC
				for r in setRooms
					for s in slotsDay[d]
						if value(u[i,r,s]) > 0.9999
							row = rowref+s
#							if d > 1
#								row = rowref+s-(sum(data[5,j] for j in 2:d))           #   data[5,j]*(d-1)
#							end
#							column = 1+(d-1)*nrRooms+r
							column = 1+r
							sh[row, column] = string("C", i)
						end
					end
				end
			end
			
#			println("Professionals allocation (p,r,s) -----------------")
			for p in 1:nrProfessionals
				for r in setRooms
					for s in slotsDay[d]
						if value(v[p,r,s]) > 0.9999
							row = rowref+s
#							if d > 1
#								row = rowref+s-(sum(data[5,j] for j in 2:d))           #   data[5,j]*(d-1)
#							end
#							column = 1+(d-1)*nrRooms+r
							column = 1+r
#							println(d, " ", row, " ", column, " === ", sh[row, column], " !!!!! ", cmp(sh[row, column], "missing"), " vs ", cmp(sh[row, column], "C"))
							if cmp(sh[row, column], "missing") == 1
								#sh[row, column] = string("__, P", p)
							else
								sh[row, column] = string(sh[row, column], ", P", p)
							end
						end
					end
				end
			end
		end
	end
	XLSX.close
	
	#Pacote do Python =======================================================================
#	wb = xl.load_workbook("instanciasProjAutismo/instProjAutismo.xlsx")
	wb = xl.load_workbook(instance_excel)
	ws = wb.get_sheet_by_name("solution") #Tem que criar essa aba na planilha Excel
	
	myborder = xl.styles.borders.Border(left=xl.styles.borders.Side(style="thin"), 
		                 right=xl.styles.borders.Side(style="thin"), 
		                 top=xl.styles.borders.Side(style="thin"), 
		                 bottom=xl.styles.borders.Side(style="thin"))
		                 
	myfillA = xl.styles.PatternFill("solid", fgColor="FFE6E6")
	myfillB = xl.styles.PatternFill("solid", fgColor="FFCCCC")
	myfillC = xl.styles.PatternFill("solid", fgColor="8BC7F7")
	myfillD = xl.styles.PatternFill("solid", fgColor="F2C80F")
	
	for d in setDays
		if d == 1 
			rowref = 3
		else
			rowref = 3*d + (d-1)*(maxSlotsInADay)
		end
		
		for colnb in 1:nrRooms
			ws.cell(row=rowref-1, column=1+colnb).fill = myfillC
			
			ws.cell(row=rowref, column=1+colnb).border = myborder
			ws.cell(row=rowref, column=1+colnb).fill = myfillD
		end
		
		for rownb in 1:maxSlotsInADay
			for colnb in 1:nrRooms
				ws.cell(row=rowref+rownb, column=1+colnb).border = myborder
				if rownb <= maxSlotsInADay/2
					ws.cell(row=rowref+rownb, column=1+colnb).fill = myfillA
				else
					ws.cell(row=rowref+rownb, column=1+colnb).fill = myfillB
				end
			end
		end
	end
#	py"""
#	$ws.column_dimensions["A"].width = 75
#	"""
mkpath("instanciasProjAutismo")
	wb.save("instanciasProjAutismo/outputSolution2.xlsx")
	# =======================================================================================

end


if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 2
        println("Uso: julia modeloAlocAutismo2.jl <input.xlsx> <sheetname>")
    else
        solve(ARGS[1], ARGS[2], 3600)
    end
end
