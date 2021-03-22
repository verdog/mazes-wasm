import Useful.sampleArray;

class RecursiveRecursiveBacktrackerMaze extends Maze {
    public static function name() {
        return "recursiverecursivebacktracker";
    }

    public static function on(grid:Grid) {
        f(grid.randomCell());
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
