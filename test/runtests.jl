using ApproximationAnalysis, Test

simpleFunction = 
quote 
    function f(x)
        y = 5.0
        a = y + x
        b = x * x
        c = a + (b*b)
    end
end

@testset "Assignment Tracking" begin
    simpleFunctionCpy = deepcopy(simpleFunction)
    symb              = GetInputSymbols(simpleFunctionCpy)
    TrackAssignmentExpr(simpleFunctionCpy, symb)
    targetFunction    = eval(simpleFunctionCpy)

    @test targetFunction(10.0) == 10015.0
    @test length(GetResults()) == 4
end

@testset "Fuzzing" begin

    # Test an attachpoint one
    simpleFunctionFuzzing = deepcopy(simpleFunction)
    ApproximationAnalysis.RemoveLineNumberNodes(simpleFunctionFuzzing)
    ApproximationAnalysis.FindAttachmentPoints(simpleFunctionFuzzing)
    ApproximationAnalysis.ReplaceTree(simpleFunctionFuzzing, 8, :(ApproximationAnalysis.FuzzInput))

    instFunction = eval(simpleFunctionFuzzing)
    SetFuzzValue(0.0)
    @test instFunction(10.0) == 10015.0
    SetFuzzValue(5.0)
    @test instFunction(10.0) == 10020.0


    # Test an attachpoint two
    simpleFunctionFuzzing = deepcopy(simpleFunction)
    ApproximationAnalysis.RemoveLineNumberNodes(simpleFunctionFuzzing)
    ApproximationAnalysis.FindAttachmentPoints(simpleFunctionFuzzing)
    ApproximationAnalysis.ReplaceTree(simpleFunctionFuzzing, 17, :(ApproximationAnalysis.FuzzInput))
    println(simpleFunctionFuzzing)
    instFunction = eval(simpleFunctionFuzzing)

    instFunction = eval(simpleFunctionFuzzing)
    SetFuzzValue(0.0)
    @test instFunction(10.0) == 10015.0
    SetFuzzValue(5.0)
    @test instFunction(10.0) == 11040.0
end