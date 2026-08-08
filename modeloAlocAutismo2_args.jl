using JuMP
using HiGHS
using XLSX

function main()
    instance_excel = length(ARGS) >= 1 ? ARGS[1] : "instProjAutismo.xlsx"
    sheetname      = length(ARGS) >= 2 ? ARGS[2] : "instancia-real-TO_DO_3_3dias"
    timelimit      = 3600

    solve(instance_excel, sheetname, timelimit)
end

function solve(instance_excel, sheetname, timelimit)
    println("reading data...")
    excelfile = XLSX.readxlsx(instance_excel)
    data = excelfile[sheetname]

    nrC = data[1,2] 
    nrT = data[2,2]  
    nrProfPerTherapy = min(nrC, 15)
    nrProfessionals = nrProfPerTherapy * nrT 
    nrRooms = data[3,2]  
    nrDays = data[4,2]  
    nrSlots = sum(data[5,j] for j in 2:(nrDays+1))
    nrShifts = sum(data[6,j] for j in 2:(nrDays+1))
    CapacShiftsPerProf = data[7,2]
    CapacShiftsPerClient = data[8,2]
    TherapyCosts = data[9,2:(nrT+1)]
    NomeSala = data[10,2:(nrT+1)]
    
    demands = []
    for i in 1:nrC
        dem_i = [(t, data[12+i,t+1]) for t in 1:nrT if data[12+i,t+1] > 0]
        push!(demands, dem_i)
    end

    setProfessionals = [i for i in 1:nrProfessionals]

    professionalsTherapy = [] 
    for p in 1:nrT
        professionals = [i for i in ((p-1)*nrProfPerTherapy+1):(p*nrProfPerTherapy)]
        push!(professionalsTherapy, professionals) 
    end
    
    profCosts = []
    for p in 1:nrT
        for i in 1:nrProfPerTherapy
            push!(profCosts, TherapyCosts[p])
        end
    end 
    
    refrow = 12 + nrC + 2
    therapyRoom = data[(refrow+1):(refrow+nrRooms), 2] 
    roomsTherapy = [] 
    for t in 1:nrT
        vectemp = [r for r in 1:nrRooms if therapyRoom[r] == t]
        push!(roomsTherapy, vectemp)
    end
    
    setSlots = [i for i in 1:nrSlots]
    setShifts = [i for i in 1:nrShifts]
    setDays = [i for i in 1:nrDays]
    setRooms = [i for i in 1:nrRooms]
    
    shiftsDay = [] 
    slotsDay = []  
    slotsShift = [] 

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
        
        push!(shiftsDay, [s for s in first_shift:last_shift]) 
        push!(slotsDay, [s for s in first_slot:last_slot])   
    end
    
    for d in 1:nrDays
        nrslots_d = data[5,1+d]
        nrshifts_d = data[6,1+d]
        
        first_slot_inday_d = (d == 1) ? 1 : sum(data[5,1+day-1] for day in 2:d) + 1
        currentslot = first_slot_inday_d
        for i in 1:nrshifts_d
            lastslot2 = currentslot + Int64(nrslots_d/nrshifts_d) - 1
            slots = [i for i in currentslot:lastslot2]
            push!(slotsShift, slots)  
            currentslot = slots[length(slots)] + 1
        end
    end
    
    println("building mathematical model...")
    # Configuração do solver HiGHS
    model = Model(HiGHS.Optimizer)
    set_optimizer_attribute(model, "time_limit", Float64(timelimit))

    @variable(model, y[p in 1:nrProfessionals], Bin)
    @variable(model, x[i in 1:nrC, p in 1:nrProfessionals], Bin)
    @variable(model, u[i in 1:nrC, r in 1:nrRooms, s in 1:nrSlots], Bin)
    @variable(model, v[i in 1:nrProfessionals, r in 1:nrRooms, s in 1:nrSlots], Bin)
    @variable(model, z[p in 1:nrProfessionals, k in 1:nrShifts], Bin)
    @variable(model, w[p in 1:nrC, k in 1:nrShifts], Bin)

    @objective(model, Min, sum(profCosts[p] * y[p] for p in setProfessionals))

    for i in 1:nrC
        for (t,q) in demands[i]
            @constraint(model, sum(x[i,p] for p in professionalsTherapy[t]) == 1)
        end
    end

    for i in 1:nrC, p in 1:nrProfessionals
        @constraint(model, x[i,p] <= y[p])
    end

    for i in 1:nrC, (t,q) in demands[i], p in professionalsTherapy[t], r in roomsTherapy[t], s in setSlots
        @constraint(model, u[i,r,s] - v[p,r,s] <= 1 - x[i,p])
    end
    
    for i in 1:nrC, (t,q) in demands[i]
        @constraint(model, sum(u[i,r,s] for r in roomsTherapy[t] for s in setSlots) == q)
    end
    
    for s in setSlots, r in setRooms
        @constraint(model, sum(u[i,r,s] for i in 1:nrC) <= 1)
        @constraint(model, sum(v[p,r,s] for p in 1:nrProfessionals) <= 1)
    end
    
    for t in 1:nrT, p in professionalsTherapy[t], r in setdiff(setRooms, roomsTherapy[t])
        @constraint(model, sum(v[p,r,s] for s in setSlots) == 0)
    end
    
    for p in 1:nrProfessionals
        @constraint(model, sum(z[p,k] for k in setShifts) <= CapacShiftsPerProf)
        for r in setRooms, k in setShifts, s in slotsShift[k]
            @constraint(model, v[p,r,s] <= z[p,k])
        end
    end
    
    for i in 1:nrC
        @constraint(model, sum(w[i,k] for k in setShifts) <= CapacShiftsPerClient)
        for r in setRooms, k in setShifts, s in slotsShift[k]
            @constraint(model, u[i,r,s] <= w[i,k])
        end
    end
    
    for p in 1:nrProfessionals, s in setSlots
        @constraint(model, sum(v[p,r,s] for r in setRooms) <= y[p])
    end
    
    for i in 1:nrC, s in setSlots
        @constraint(model, sum(u[i,r,s] for r in setRooms) <= 1)
    end
    
    println("solving mathematical model...")
    optimize!(model)
    
    maxSlotsInADay = maximum([length(slotsDay[d]) for d in setDays])
    
    # Escreve a solução encontrada na planilha de volta
    XLSX.openxlsx(instance_excel, mode="rw") do xf
        sh = xf["solution"]
        for row in 1:300, column in 1:100
            sh[row, column] = string("")
        end
        
        for d in setDays
            rowref = 3*d
            for r in eachindex(therapyRoom)
                sh[rowref+maxSlotsInADay*(d-1), r+1] = NomeSala[therapyRoom[r]]
            end
            
            for i in 1:nrC, r in setRooms, s in slotsDay[d]
                if value(u[i,r,s]) > 0.9999
                    sh[rowref+s, 1+r] = string("C", i)
                end
            end
            
            for p in 1:nrProfessionals, r in setRooms, s in slotsDay[d]
                if value(v[p,r,s]) > 0.9999
                    row, column = rowref+s, 1+r
                    if cmp(sh[row, column], "missing") == 1
                        sh[row, column] = string("P", p)
                    else
                        sh[row, column] = string(sh[row, column], ", P", p)
                    end
                end
            end
        end
    end
end

main()
