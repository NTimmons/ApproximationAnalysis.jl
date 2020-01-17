module ApproximationAnalysis

####################################
# Automatic Expr Fuzzing
####################################
include("Fuzzing.jl")

# Main Functions
export ReplaceTree
export FindAttachmentPoints
export SetFuzzValue
export FuzzInput
export ZeroExpr

# Helpers
export RemoveLineNumberNodes
export displayall

####################################
# Automatic Value Tracking for assignments
####################################
include("AssignmentTracking.jl")

# Types
export LogType
# Main Functions
export TrackAssignmentExpr, GetInputSymbols
export GetResults, ClearResults

end
