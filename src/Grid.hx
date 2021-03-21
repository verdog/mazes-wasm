class Grid {
    public var rows(default, null):Int;
    public var columns(default, null):Int;

    private var grid:Array<Array<Cell>>;

    public function new(rows:Int, columns:Int) {
        this.rows = rows;
        this.columns = columns;

        grid = prepareGrid();
        configureCells();
    }

    public function at(row:Int, column:Int) {
        if (row < 0 || row >= rows) return null;
        if (column < 0 || column >= columns) return null;

        return grid[row][column];
    }

    public function row(row:Int) {
        if (row > rows) return null;

        return grid[row];
    }

    public function randomCell() {
        var row = Std.random(rows);
        var column = Std.random(grid[row].length);
        return at(row, column);
    }

    public function size() {
        return rows * columns;
    }

    private function prepareGrid() {
        var a = new Array<Array<Cell>>();

        a.resize(rows);

        for (row in 0...rows) {
            a[row] = new Array<Cell>();
            a[row].resize(columns);
            for (col in 0...columns) {
                a[row][col] = new Cell(row, col);
            }
        }

        return a;
    }

    private function configureCells() {
        for (cell in new GridIterator(this)) {
            var row = cell.row;
            var col = cell.column;

            cell.north = at(row - 1, col);
            cell.south = at(row + 1, col);
            cell.east  = at(row    , col + 1);
            cell.west  = at(row    , col - 1);
        }
    }

    public function contentsOf(cell:Cell) {
        return " ";
    }

    public function string() {
        var output = "+" + [for (_ in 0...columns) "---+"].join("") + "\n";

        for (row in new GridRowIterator(this)) {
            var top = "|";
            var bottom = "+";

            for (cell in row) {
                if (cell == null) cell = new Cell(-1, -1);

                var body = ' ${contentsOf(cell)} ';
                var east_bound = if (cell.isLinked(cell.east)) " " else "|";

                top += body;
                top += east_bound;

                var south_bound = if (cell.isLinked(cell.south)) "   " else "---";
                var corner = "+";

                bottom += south_bound;
                bottom += corner;
            }

            output += top + "\n";
            output += bottom + "\n";
        }

        return output;
    }

    public function print() {
        Sys.print(string());
    }
}

class GridIterator {
    var grid:Grid;
    var row:Int;
    var column:Int;

    public function new(grid:Grid) {
        this.grid = grid;
        row = 0;
        column = 0;
    }

    public function hasNext() {
        return row < grid.rows && column < grid.columns;
    }

    public function next() {
        var thisRow = row;
        var thisCol = column++;

        if (column >= grid.columns) {
            row++;
            column = 0;
        }

        return grid.at(thisRow, thisCol);
    }
}

class GridRowIterator {
    var grid:Grid;
    var row:Int;

    public function new(grid:Grid) {
        this.grid = grid;
        row = 0;
    }

    public function hasNext() {
        return row < grid.rows;
    }

    public function next() {
        return grid.row(row++);
    }
}
