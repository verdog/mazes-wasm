import bitmap.Draw.RectangleShape;
import Grid.GridIterator;
import format.png.Data.Color;
import sys.io.File;
import sys.io.FileOutput;
import bitmap.*;

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

    public function backgroundColorFor(cell:Cell) {
        return null;
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

    private function rect(x1, y1, x2, y2, color, lineThickness:Int) {
        return {
            x: x1 - Math.floor(lineThickness/2),
            y: y1 - Math.floor(lineThickness/2),
            width: Useful.intAbs(x2 - x1) + Math.ceil(lineThickness/2),
            height: Useful.intAbs(y2 - y1) + Math.ceil(lineThickness/2),
            c: color,
            blend: null,
            fill: true
        }
    }
    
    public function png() {
        var file = File.write("output.png");
        var margin = 16;
        var cellSize = 32;
        var lineThickness = 4;
    
        var backgroundColor = new bitmap.Color(0xffffffff);
        var wallColor = new bitmap.Color(0x222222ff);
    
        var PNG = new PNGBitmap(
            2*margin + cellSize*columns, 
            2*margin + cellSize*rows);
        
        // background
        PNG.fill(backgroundColor);
    
        // cells
        for (mode in ["backgrounds", "walls"]) {
            for (cell in new GridIterator(this)) {
                var x1 = cell.column * cellSize + margin;
                var x2 = (cell.column + 1) * cellSize + margin;
                var y1 = cell.row * cellSize + margin;
                var y2 = (cell.row + 1) * cellSize + margin;
                
                if (mode == "backgrounds") {
                    var color = backgroundColorFor(cell);
                    if (color != null) {
                        PNG.draw.rectangle(rect(x1, y1, x2, y2, color, lineThickness));
                    }
                } else {
                    // mode == walls
                    // top wall
                    if (cell.north == null) PNG.draw.rectangle(rect(x1, y1, x2, y1, wallColor, lineThickness));
                    if (cell.west == null) PNG.draw.rectangle(rect(x1, y1, x1, y2, wallColor, lineThickness));
                    
                    // bottom walls
                    if (!cell.isLinked(cell.east)) PNG.draw.rectangle(rect(x2, y1, x2, y2, wallColor, lineThickness));
                    if (!cell.isLinked(cell.south)) PNG.draw.rectangle(rect(x1, y2, x2, y2, wallColor, lineThickness));
                }
            }
        }
    
        PNG.save(file);
        file.close();
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
