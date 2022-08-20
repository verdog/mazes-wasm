import Useful.sampleArray;
import Grid.GridRowIterator;

class SidewinderMaze extends Maze {
    public static var name(default, null) = "sidewinder";
    
    public static function on(grid:Grid) {
        for (row in new GridRowIterator(grid)) {
            var run = [];

            for (cell in row) {
                run.push(cell);

                var at_east = cell.east == null;
                var at_north = cell.north == null;
                var should_close = 
                    at_east || (!at_north && Std.random(2) == 0);

                if (should_close) {
                    var member = sampleArray(run);
                    if (member.north != null) member.link(member.north);
                    run = [];
                } else {
                    cell.link(cell.east);
                }
            }
        }
    }
}