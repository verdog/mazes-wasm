import Useful.sampleArray;
import Grid.GridIterator;

class WilsonMaze extends Maze {
    public static var name(default, null) = "wilson";
    
    public static function on(grid:Grid) {
        var unvisited = [];
        for (cell in new GridIterator(grid)) {
            unvisited.push(cell);
        }

        var first = sampleArray(unvisited);
        unvisited.remove(first);

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
            }
        }
    }
}
