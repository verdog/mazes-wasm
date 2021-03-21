import Useful.sampleArray;

class AldousBroderMaze {
    public static function on(grid:Grid) {
        var cell = grid.randomCell();
        var unvisited = grid.size() - 1;

        var step = Std.int(unvisited/64);
        if (step == 0) step = 1;
        var thresh = unvisited - step;
        Sys.print("-");

        while (unvisited > 0) {
            var neighbor = sampleArray(cell.neighbors());

            if (!neighbor.links().hasNext()) {
                cell.link(neighbor);
                unvisited--;

                if (unvisited < thresh) {
                    thresh = if (thresh - step < 1) 1 else thresh - step;
                    Sys.print("-");
                }
            }

            cell = neighbor;
        }
    }
}
