import bitmap.Draw.RectangleShape;
import Grid.GridIterator;
import format.png.Data.Color;
import sys.io.File;
import sys.io.FileOutput;
import bitmap.*;

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

function gridToPNG(grid:Grid) {
    var file = File.write("output.png");
    var margin = 16;
    var cellSize = 32;
    var lineThickness = 8;

    var backgroundColor = new bitmap.Color(0xffffffff);
    var wallColor = new bitmap.Color(0x222222ff);

    var PNG = new PNGBitmap(
        2*margin + cellSize*grid.columns, 
        2*margin + cellSize*grid.rows);
    
    // background
    PNG.fill(backgroundColor);

    // cells
    for (cell in new GridIterator(grid)) {
        var x1 = cell.column * cellSize + margin;
        var x2 = (cell.column + 1) * cellSize + margin;
        var y1 = cell.row * cellSize + margin;
        var y2 = (cell.row + 1) * cellSize + margin;

        // top wall
        if (cell.north == null) PNG.draw.rectangle(rect(x1, y1, x2, y1, wallColor, lineThickness));
        if (cell.west == null) PNG.draw.rectangle(rect(x1, y1, x1, y2, wallColor, lineThickness));

        // bottom walls
        if (!cell.isLinked(cell.east)) PNG.draw.rectangle(rect(x2, y1, x2, y2, wallColor, lineThickness));
        if (!cell.isLinked(cell.south)) PNG.draw.rectangle(rect(x1, y2, x2, y2, wallColor, lineThickness));
    }

    PNG.save(file);
    file.close();
}