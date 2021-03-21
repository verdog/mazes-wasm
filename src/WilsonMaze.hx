import Useful.sampleArray;
import Grid.GridIterator;

class WilsonMaze {
    public static function on(grid:Grid) {
        var unvisited = [];
        for (cell in new GridIterator(grid)) {
            unvisited.push(cell);
        }

        var first = sampleArray(unvisited);
        unvisited.remove(first);

        var step = Std.int(unvisited.length/64);
        if (step == 0) step = 1;
        var thresh = unvisited.length - step;
        Sys.print("-");

        while (unvisited.length > 0) {
            var cell = sampleArray(unvisited);
            var path = [cell];

            while (unvisited.indexOf(cell) != -1) {
                cell = sampleArray(cell.neighbors());
                var position = path.indexOf(cell);

                if (position != -1) {
                    path = path.slice(0, position + 1);
                } else {
                    path.push(cell);
                }
            }

            for (index in 0...path.length - 1) {
                path[index].link(path[index + 1]);
                unvisited.remove(path[index]);

                if (unvisited.length < thresh) {
                    thresh = if (thresh - step < 1) 1 else thresh - step;
                    Sys.print("-");
                }
            }
        }

        Sys.print("\n");
    }
}
