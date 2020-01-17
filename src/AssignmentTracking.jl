# Tracking all assignments

### Struct to hold entries for specific variable on specific line
### Warning: If you do something like:
#                       ` a = 1 + a; a = 1 + a; a = 1 + a `
#                Firstly: Why? Oh God why?
#                Secondly: All assignments to a will be kept in the same log which is probably
#                          not good.
#                
#            This can be resolved by using some hash of the id, expr, line, and place in the 
#            parents expr but I am currently trying to keep this code simple until I know what
#            form I want it to be at the end. So HEED THIS WARNING... for now.
mutable struct LogType
    name::AbstractString
    line::Int64
    values::Array{Any,1}
end

### Global Results Store
### Note: This should be an input to the function which marks up the input Expr
#         but again, keeping this simple for now.
DictType = Dict{AbstractString, LogType}
resultDict = DictType()
GetResults() = resultDict
function ClearResults()::DictType 
    global resultDict
    resultDict = DictType()
end

# Returns an array representing the input symbols for this function
function GetInputSymbols(expr)
    inputSymbols = []
    if(typeof(expr) == LineNumberNode)
        return inputSymbols
    elseif(typeof(expr) == Expr)
         for i in 1:length(expr.args)
            if(typeof(expr.args[i]) == Expr)
                if(expr.args[i].head == :function)
                    inputSymbols = expr.args[i].args[1].args[2:end]
                    return inputSymbols
                else
                    inputSymbols = GetInputSymbols(expr.args[1])
                    if(length(inputSymbols) > 0)
                        return inputSymbols
                    end
                end 
            end
        end
    end

    return inputSymbols
end



### This is the function which is injected into the source Expr tree.
### It takes the current name and line of the assignment being performed
### and either creates or updates the entry for a specific assignment point.
function AddUpdateEntry(name::AbstractString, line::Int64, value::Any, inputsValues...)
    global resultDict
    try
        push!(resultDict[name].values, (inputsValues, value, typeof(value)) )
    catch error
        if isa(error, KeyError)
            resultDict[name] = LogType(name, line, [ (inputsValues, value, typeof(value) ) ] )
        end
    end
        
    return value
end

### Recurses through the given expression and replaces calls in the form:
#          line 9:     x = a 
# with:
#               x = AddUpdateEntry('x', 9, $a)
### Changes the input Expr in-place.
### Does not track nested assignments.
function TrackAssignmentExpr(expr, inputsValues, lastline=-1)::Int64
    
    # If this expr is a LineNumberNode we update which line we are currently on and move on
    if(typeof(expr) == LineNumberNode)
        lastline = expr.line
        return lastline
        
    # Else, if it is an expression we walk the expression array looking for assigments to track
    elseif(typeof(expr) == Expr) 
        if(expr.head == :(=))
            println("Tracking assignments to $(expr.args[1]) on line $(lastline)")
            key = "[$(lastline)]: $(expr.args[1]) = $(expr.args[2])"
            replacementExpr = Expr(:call, AddUpdateEntry, key, lastline, expr.args[2], inputsValues...)
            expr.args[2]    = replacementExpr
        else
             for i in 1:length(expr.args)
                 if(typeof(expr.args[i])== Expr)
                     # If the type of this expression is an assignment then we replace its target 
                     # with our tracking function.

                     # Recurse down the tree.
                     lastline = TrackAssignmentExpr(expr.args[i], inputsValues, lastline)
                 elseif(typeof(expr.args[i]) == LineNumberNode)
                     lastline = expr.args[i].line
                 end
             end
         end
    end
    
    return lastline
end
