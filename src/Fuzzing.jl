# Automatic Fuzzing Functions

# Global fuzz values used in the provided "FuzzInput" override function.
# other functions can be written or custom fuzzing implemented but this simple
# one is enough for our current needs and keeps the module relatively generic.
globalFuzzVal =  0.0
function SetFuzzValue(x) 
    global globalFuzzVal
    globalFuzzVal = x
end
FuzzInput(t)  = t + oftype(t,globalFuzzVal);
ZeroExpr(t)   = oftype(t,0.0)


### Small function to loop through all Expr nodes and remove any which
### are LineNumberNodes.
### We use this to simplify Expr's which are generated using the `quote` notation.
### Modifies the the tree in-place.
function RemoveLineNumberNodes(expr)
    if(typeof(expr) == Expr)
         # Handle expressions
        deleteat!(expr.args, findall(x->typeof(x)==LineNumberNode , expr.args))
        for i in 1:length(expr.args)
            RemoveLineNumberNodes(expr.args[i])
        end
    end
end

### Loops through the Expr tree and asigns an ID to each node which valid
### for automated fuzzing.
### Returns: An array of possible attachment points and their assigned IDs
function FindAttachmentPoints(expr, maxid = 0, symbolExclusion = names(Base))
    ids = []
    id = maxid
    if(typeof(expr) == Expr)
         # Handle expressions
         push!(ids,(id,expr))   
         for i in 1:length(expr.args)
             id = id + 1
             newIds, id = FindAttachmentPoints(expr.args[i], id, symbolExclusion)
             ids = vcat(ids, newIds)
         end
    elseif(typeof(expr) == Symbol)
         # Handle Symbols - We cant fuzz functions directly. Only the result through :call
         if ( !(expr in symbolExclusion) )
             push!(ids,(id,expr))
         end
    elseif ( isa( (expr), Number ) )
         push!(ids, (id,expr))  
    else
         println("Unknown type submitted: $(typeof(expr))")
    end
        
    return ids, id
end

### Loops through the Expr tree and transforms any expression 'x' at the given id
### to $functionName(x)
### Modifies the tree in-place.
exitcode = 12345678
function ReplaceTree(expr, replacementID, functionName, maxid = 0)
    id = maxid
    if(id == exitcode) return exitcode end
    if(typeof(expr) == Expr)
         for i in 1:length(expr.args)
             id = id + 1
             if(id == replacementID)
                 fuzzTarget = expr.args[i]
                 replacementExpr = Expr(:call, functionName, fuzzTarget)
                 expr.args[i] = replacementExpr
                 return exitcode
             elseif(id > replacementID)
                 if(id != exitcode)
                     println("$id -> Unable to replace function: $(expr)")
                 end
                 return exitcode
             end
            
             id = ReplaceTree(expr.args[i], replacementID, functionName, id)
             if(id == exitcode) return exitcode end
         end
    end
    
    return id
end

############################################
### WARNING: THIS FUNCTION NEEDS SOME LOVE.
#   Stick with individual usecases using ReplaceTree for now. 
#   -> Until we find a nice way to organise this.
############################################
### Takes a given expr representing a function and performs fuzzing on each 
### possible sub-expression. The results are then returned.
### Inputs: 
#           - expr : A valid function AST 
#           - inputRange : The input range to test the function
#           - fuzzRange  : The range of values to offset the result of each subexpression.
#                          This is used to determine if small changes in the value of each
#                          subexpression result in large changes to output.
#
#  Returns: Table of all sub-expressions with an array for input, output, fuzzvalue, fuzzed output.
function FuzzTestAll(expr, verbose=false, inputRange = 0.0:0.01:1.0, fuzzRange  = -0.5:0.01:0.5)
        if(verbose) println("Find Attachment Points") end
        res, maxid       = FindAttachmentPoints(expr)
        attachPointCount = length(res)
        if(verbose) println("Found $attachPointCount attach points (2 Forced Invalid)") end

        resultsTable = []
        for p in res[3:end]
            if(verbose) println("Fuzzing:\n $p") end
            tCopyFuzz = deepcopy(expr)
            
            if(verbose) println("Replacing Tree") end
            ReplaceTree(tCopyFuzz, p[1] , :FuzzInput)
            if(verbose) println("Tree Replaced") end
            
            if(verbose) println("Validating...") end
            try
                execFunc  = eval(tCopyFuzz)
                if(verbose) println("Success...") end
                
                ptable = []
                for inp in inputRange
                    globalFuzzVal = 0.0
                    sourceResult  = execFunc(x)
                    fuzzRes = []
                    for fuzz in fuzzRange
                        globalFuzzVal = fuzz
                        fuzzResult    = execFunc(x)
                        dif           = (sourceResult - fuzzResult)
                        push!(fuzzRes, dif)
                    end
                    push!(ptable, (inp, (fuzzRange, fuzzRes)))
                end
                
                push!(resultsTable, (p, ptable))
            catch e
                if(typeof(e) ==  ErrorException)
                   println("ErrorException: Failed to replace $p : $(e.msg)")
                else
                    println("Unhandled Exception Type with subexpr $(p): ")
                    println(e)
                end
            end
        end

        println("Fuzzed $(length(resultsTable))/$(attachPointCount) possible locations)")
        resultsTable
end

# Helper macro for displaying all graphs which are stored in an array.
macro displayall(graphlist, zlims = ())
    quote
        for g in $graphlist
            grp = plot(g, zlim=zlims)
            display(grp)
        end
    end
end
