import Useful.sampleArray;

class RecursiveRecursiveBacktrackerMaze extends Maze {
    public static var name(default, null) = "recursiverecursivebacktracker";

    public static function on(grid:Grid, start_at:Cell = null) {
        if (start_at == null) {
            f(grid.randomCell());
        } else {
            f(start_at);
        }
    }

    private static function f(cell:Cell) {
        var neighbors = cell.neighbors().filter(function ff(c) return !c.links().hasNext());

        while (neighbors.length > 0) {
            var neighbor = sampleArray(neighbors);
            cell.link(neighbor);
            f(neighbor);
            neighbors = cell.neighbors().filter(function ff(c) return !c.links().hasNext());
        }
    }
}
