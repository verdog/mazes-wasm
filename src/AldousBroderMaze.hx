import Useful.sampleArray;

class AldousBroderMaze extends Maze {
    public static function name() {
        return "aldousbroder";
    }
    
    public static function on(grid:Grid) {
        var cell = grid.randomCell();
        var unvisited = grid.size() - 1;

        while (unvisited > 0) {
            var neighbor = sampleArray(cell.neighbors());

            if (!neighbor.links().hasNext()) {
                cell.link(neighbor);
                unvisited--;
            }

            cell = neighbor;
        }
    }
}
