import bitmap.PNGBitmap;
import sys.io.File;

class PolarGrid extends ColoredGrid {
    public function new(rows) {
        super(rows, 1);
    }

    private override function prepareGrid() {
        var rows = new Array<Array<Cell>>();
        rows.resize(super.rows);

        var rowHeight = 1.0 / super.rows;
        rows[0] = [ new PolarCell(0, 0) ];

        for (r in 1...super.rows) {
            var radius = r / super.rows;
            var circumference = 2 * Math.PI * radius;

            var prevCount = rows[r - 1].length;
            var estCellWidth = circumference / prevCount;
            var ratio = Math.round(estCellWidth / rowHeight);

            var cells = prevCount * ratio;
            rows[r] = [for (c in 0...cells) new PolarCell(r, c)];
        }

        return rows;
    }

    private override function configureCells() {
        for (cell in this) {
            var cell = cast(cell, PolarCell);
            var thisRow = cell.row;
            var thisCol = cell.column;

            if (thisRow > 0) {
                cell.cw = at(thisRow, thisCol + 1);
                cell.ccw = at(thisRow, thisCol - 1);

                var ratio = row(thisRow).length / row(thisRow - 1).length;
                var parent = cast(at(thisRow - 1, Std.int(thisCol / ratio)), PolarCell);
                parent.outward.push(cell);
                cell.inward = parent;
            }
        }
    }

    public override function at(row:Int, column:Int) {
        if (row < 0 || row >= grid.length) return null;
        return grid[row][column % grid[row].length];
    }

    public override function randomCell():Cell {
        var row = Std.random(rows);
        var col = Std.random(grid[row].length);
        return grid[row][col];
    }

    public override function png(filename:String, cellSize = 32) {
        var file = File.write(filename);
        var imgSize = 2 * rows * cellSize;

        var backgroundColor = new bitmap.Color(0xffffffff);
        var wallColor = new bitmap.Color(0x000000ff);

        var img = new PNGBitmap(imgSize + 1, imgSize + 1);
        img.fill(backgroundColor);

        var center = Std.int(imgSize / 2);

        for (cell in this) {
            if (cell.row == 0) continue;

            var cell = cast(cell, PolarCell);

            var theta    = 2 * Math.PI / grid[cell.row].length;
            var innerRad = cell.row * cellSize;
            var outerRad = (cell.row + 1) * cellSize;
            var thetaCCW = cell.column * theta;
            var thetaCW  = (cell.column + 1) * theta;

            var ax = center + Std.int(innerRad * Math.cos(thetaCCW));
            var ay = center + Std.int(innerRad * Math.sin(thetaCCW));
            var bx = center + Std.int(outerRad * Math.cos(thetaCCW));
            var by = center + Std.int(outerRad * Math.sin(thetaCCW));
            var cx = center + Std.int(innerRad * Math.cos(thetaCW));
            var cy = center + Std.int(innerRad * Math.sin(thetaCW));
            var dx = center + Std.int(outerRad * Math.cos(thetaCW));
            var dy = center + Std.int(outerRad * Math.sin(thetaCW));
            
            if (!cell.isLinked(cell.inward)) img.draw.line(ax, ay, cx, cy, wallColor);
            if (!cell.isLinked(cell.cw)) img.draw.line(cx, cy, dx, dy, wallColor);
        }

        circle(img, center, center, rows * cellSize, wallColor);
        img.save(file);
        file.close();
    }

    private function circle(img:PNGBitmap, x, y, radius, color) {
        var inc = 2*Math.PI / grid[grid.length - 1].length;
        var th = 0.0;

        while (th < Math.PI * 2) {
            var x1 = Std.int(x + radius * Math.cos(th));
            var y1 = Std.int(y + radius * Math.sin(th));
            var x2 = Std.int(x + radius * Math.cos(th + inc));
            var y2 = Std.int(y + radius * Math.sin(th + inc));

            img.draw.line(x1, y1, x2, y2, color);

            th += inc;
        }
    }
}