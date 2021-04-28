import Useful.sampleArray;

class RecursiveBacktrackerMaze extends Maze {
    public static var name(default, null) = "recursivebacktracker";

    public static function on(grid:Grid) {
        var stack = [];
        stack.push(grid.randomCell());

        while (stack.length > 0) {
            var current = stack[stack.length - 1];
            var neighbors = current.neighbors().filter(function f(c) return !c.links().hasNext());

            if (neighbors.length == 0) {
                stack.pop();
            } else {
                var neighbor = sampleArray(neighbors);
                current.link(neighbor);
                stack.push(neighbor);
            }
        }
    }
}