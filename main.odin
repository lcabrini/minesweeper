package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

WIDTH :: 1024
HEIGHT :: 768
TITLE :: "Minewsweeper"

MIDX :: WIDTH / 2
MIDY :: HEIGHT / 2

CELL_SIZE :: 32
COUNTER_SIZE :: 20

Flag :: enum {
    NONE,
    FLAG,
    MAYBE,
}

GameState :: enum {
    STARTED,
    LOST,
    WON,
}

GameScreen :: enum {
    INIT,
    GAME,
    GAMEOVER,
    HISCORES,
}

Cell :: struct {
    x: i32,
    y: i32,
    has_mine: bool,
    exploded: bool,
    flag: Flag,
    opened: bool,
    adjacent_mines: i32,
}

Game :: struct {
    screen: GameScreen,
    grid_width: i32,
    grid_height: i32,
    mine_count: int,
    found: int,
    state: GameState,
    timer_started: bool,
    start_time: time.Time,
    seconds: f64,
    exploded_tex: rl.Texture,
    flag_tex: rl.Texture,
    incorrect_tex: rl.Texture,
    maybe_tex: rl.Texture,
    mine_tex: rl.Texture,
    grid: [dynamic]Cell,
    cheat_mode: bool,
    margin_x: i32,
    margin_y: i32
}

main :: proc() {
    game := Game{}
    if len(os.args[1:]) > 0 && os.args[1] == "cheat" {
        game.cheat_mode = true
    }

    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WIDTH, HEIGHT, TITLE)
    rl.SetTargetFPS(60)

    game.screen = GameScreen.INIT
    game.exploded_tex = rl.LoadTexture("exploded.png")
    game.flag_tex = rl.LoadTexture("flag.png")
    game.incorrect_tex = rl.LoadTexture("incorrect.png")
    game.maybe_tex = rl.LoadTexture("maybe.png")
    game.mine_tex = rl.LoadTexture("mine.png")

    for !rl.WindowShouldClose() {
        switch game.screen {
            case .INIT:
                //init_input(&game)
            case .GAME:
                input(&game)
                update(&game)
            case .GAMEOVER:
            case .HISCORES:
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        #partial switch game.screen {
            case .INIT:
                draw_init(&game)
            case .GAME:
                draw(&game)
            case .GAMEOVER:
            case .HISCORES:
        }

        rl.EndDrawing()
    }

    rl.UnloadTexture(game.exploded_tex)
    rl.UnloadTexture(game.flag_tex)
    rl.UnloadTexture(game.incorrect_tex)
    rl.UnloadTexture(game.maybe_tex)
    rl.UnloadTexture(game.mine_tex)
    rl.CloseWindow()
}

input :: proc(game: ^Game) {
    if game.state == .STARTED && rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        if !game.timer_started {
            game.start_time = time.now()
            game.timer_started = true
        }

        cell := get_mouse_cell(game)
        if cell != nil && cell.x >= 0 && cell.x < game.grid_width && cell.y >= 0 && cell.y < game.grid_height {
            if cell.has_mine {
                cell.exploded = true
                game.state = .LOST
            } else if cell.adjacent_mines > 0 {
                cell.opened = true
            } else {
                open_cells(game, &game.grid, cell.y, cell.x)
            }

            if grid_complete(&game.grid) do game.state = .WON
        }
    }

    if game.state == .STARTED && rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) {
        cell := get_mouse_cell(game)
        if cell != nil {
            if !cell.opened {
                switch cell.flag {
                    case .NONE:
                        if game.found < game.mine_count {
                            cell.flag = .FLAG
                            game.found += 1
                        } else {
                            cell.flag = .MAYBE
                        }
                    case .FLAG:
                        cell.flag = .MAYBE
                        game.found -= 1
                    case .MAYBE:
                        cell.flag = .NONE
                }
            }
        }

        if grid_complete(&game.grid) do game.state = .WON
    }
}

update :: proc(game: ^Game) {
    if game.timer_started && game.state != .LOST && game.state != .WON {
        now := time.now()
        duration := time.diff(game.start_time, now)
        game.seconds = time.duration_seconds(duration)
    }
}

draw :: proc(game: ^Game) {
    counter_colors: []rl.Color = {
        rl.BLANK,
        rl.RAYWHITE,
        rl.YELLOW,
        rl.ORANGE,
        rl.BLUE,
        rl.GREEN,
        rl.PURPLE,
        rl.RED,
        rl.BROWN,
    }

    draw_grid(game)

    for cell in game.grid {
        if game.cheat_mode && cell.has_mine {
            x := cell.x * CELL_SIZE + game.margin_x + 1
            y := cell.y * CELL_SIZE + game.margin_y + 1
            w: i32 = CELL_SIZE - 2
            h: i32 = CELL_SIZE - 2
            rl.DrawRectangle(x, y, h, w, rl.DARKGRAY)
        } else if cell.opened && cell.adjacent_mines > 0 {
            s := strings.clone_to_cstring(fmt.tprint(cell.adjacent_mines))
            tw := rl.MeasureText(s, COUNTER_SIZE)
            x := game.margin_x + cell.x * CELL_SIZE + (CELL_SIZE / 2 - tw / 2)
            y := game.margin_y + cell.y * CELL_SIZE + (CELL_SIZE / 2 - COUNTER_SIZE / 2)
            rl.DrawText(s, x, y, COUNTER_SIZE, counter_colors[cell.adjacent_mines])
        } else if !cell.opened {
            x := game.margin_x + cell.x * CELL_SIZE + 1
            y := game.margin_y + cell.y * CELL_SIZE + 1
            h := i32(CELL_SIZE - 2)
            w := i32(CELL_SIZE - 2)
            rl.DrawRectangle(x, y, w, h, rl.GRAY)
        }

        #partial switch cell.flag {
            case .FLAG:
                x := game.margin_x + cell.x * CELL_SIZE + 1
                y := game.margin_y + cell.y * CELL_SIZE + 1
                rl.DrawTexture(game.flag_tex, x, y, rl.RAYWHITE)
            case .MAYBE:
                x := game.margin_x + cell.x * CELL_SIZE + 1
                y := game.margin_y + cell.y * CELL_SIZE + 1
                rl.DrawTexture(game.maybe_tex, x, y, rl.RAYWHITE)
        }

        if cell.exploded {
            x := game.margin_x + cell.x * CELL_SIZE + 1
            y := game.margin_y + cell.y * CELL_SIZE + 1
            rl.DrawTexture(game.exploded_tex, x, y, rl.RAYWHITE)
        }
    }

    rl.DrawRectangle(0, HEIGHT - 30, WIDTH, HEIGHT - 30, rl.BLUE)
    stats := rl.TextFormat("%d of %d mines found", game.found, game.mine_count)
    rl.DrawText(stats, 100, HEIGHT - 25, 20, rl.RAYWHITE)

    play_time := rl.TextFormat("Time: %03d", i32(game.seconds))
    rl.DrawText(play_time, 800, HEIGHT - 25, 20, rl.RAYWHITE)
}

init_grid :: proc(game: ^Game) {
    for r in 0..<game.grid_height {
        for c in 0..<game.grid_width {
            cell := Cell{}
            cell.x = c
            cell.y = r
            append(&game.grid, cell)
        }
    }
}

draw_grid :: proc(game: ^Game) {
    for r: i32 = 0; r <= game.grid_height; r += 1 {
        rl.DrawLine(game.margin_x, r*CELL_SIZE+game.margin_y, game.grid_width*CELL_SIZE+game.margin_x, r*CELL_SIZE+game.margin_y, rl.RAYWHITE)
    }

    for c: i32 = 0; c <= game.grid_width; c += 1 {
        rl.DrawLine(c*CELL_SIZE+game.margin_x, game.margin_y, c*CELL_SIZE+game.margin_x, game.grid_height*CELL_SIZE+game.margin_y, rl.RAYWHITE)
    }
}

get_mouse_cell :: proc(game: ^Game) -> ^Cell {
    mp := rl.GetMousePosition()
    x := mp.x >= f32(game.margin_x) ? i32((mp.x - f32(game.margin_x)) / CELL_SIZE) : -1
    y := mp.y >= f32(game.margin_y) ? i32((mp.y - f32(game.margin_y)) / CELL_SIZE) : -1

    for &cell in game.grid {
        if x == cell.x && y == cell.y {
            return &cell
        }
    }

    return nil
}

place_mines :: proc(game: ^Game) {
    placed := 0
    outer: for {
        x := rl.GetRandomValue(0, game.grid_width-1)
        y := rl.GetRandomValue(0, game.grid_height-1)

        for &cell in game.grid {
            if cell.x == x && cell.y == y {
                if cell.has_mine do continue outer

                cell.has_mine = true
                placed += 1
                break
            }
        }

        if placed >= game.mine_count do return
    }
}

count_adjacent_mines :: proc(game: ^Game) {   //grid: ^[dynamic]Cell) {
    grid := &game.grid
    for i: i32 = 0; i < i32(len(grid)); i += 1 {
        cell := &grid[i]
        if !cell.has_mine {
            count: i32 = 0
            if cell.y - 1 >= 0 {
                if cell.x - 1 >= 0 && grid[i-game.grid_width-1].has_mine do count += 1
                if grid[i-game.grid_width].has_mine do count += 1
                if cell.x + 1 < game.grid_width && grid[i-game.grid_width+1].has_mine do count += 1
            }

            if cell.x - 1 >= 0 && grid[i-1].has_mine do count += 1
            if cell.x + 1 < game.grid_width && grid[i+1].has_mine do count += 1

            if cell.y + 1 < game.grid_height {
                if cell.x - 1 >= 0 && grid[i+game.grid_width-1].has_mine do count += 1
                if grid[i+game.grid_width].has_mine do count += 1
                if cell.x + 1 < game.grid_width && grid[i+game.grid_width+1].has_mine do count += 1
            }

            cell.adjacent_mines = count
        }
    }
}

open_cells :: proc(game: ^Game, grid: ^[dynamic]Cell, row, col: i32) {
    idx := row * game.grid_width + col

    if row < 0 || row >= game.grid_height || col < 0 || col >= game.grid_width {
        return
    }

    if grid[idx].has_mine {
        return
    }

    if grid[idx].opened {
        return
    }

    grid[idx].opened = true
    if grid[idx].flag != .NONE {
        if grid[idx].flag == .FLAG do game.found -= 1
        grid[idx].flag = .NONE
    }

    if grid[idx].adjacent_mines > 0 {
        return
    }

    open_cells(game, grid, row-1, col-1)
    open_cells(game, grid, row-1, col)
    open_cells(game, grid, row-1, col+1)
    open_cells(game, grid, row, col-1)
    open_cells(game, grid, row, col+1)
    open_cells(game, grid, row+1, col-1)
    open_cells(game, grid, row+1, col)
    open_cells(game, grid, row+1, col+1)
}

grid_complete :: proc(grid: ^[dynamic]Cell) -> bool {
    fmt.println("checking...")
    for cell, i in grid {
        switch {
            case cell.flag == .FLAG && !cell.has_mine:
                fmt.println("wrongly flagged cell found")
                return false
            case cell.flag != .FLAG && cell.has_mine:
                fmt.printfln("unflagged mine found: %d", i)
                return false
            case !cell.opened && cell.flag != .FLAG:
                fmt.printfln("unopened cell found: %d", i)
                return false
        }
    }

    fmt.println("were are good")
    return true
}

draw_init :: proc(game: ^Game) {
    if rl.GuiButton(rl.Rectangle{100, 10, WIDTH-200, 40}, "Easy") {
        game.state = nil
        game.grid_width = 9
        game.grid_height = 9
        game.mine_count = 10
        game.margin_x = MIDX - game.grid_width * CELL_SIZE / 2
        game.margin_y = MIDY - game.grid_height * CELL_SIZE / 2
        init_grid(game)
        place_mines(game)
        count_adjacent_mines(game)
        game.screen = GameScreen.GAME
    }

     if rl.GuiButton(rl.Rectangle{100, 60, WIDTH-200, 40}, "Medium") {
        game.state = nil
        game.grid_width = 16
        game.grid_height = 16
        game.mine_count = 40
        game.margin_x = MIDX - game.grid_width * CELL_SIZE / 2
        game.margin_y = MIDY - game.grid_height * CELL_SIZE / 2
        init_grid(game)
        place_mines(game)
        count_adjacent_mines(game)
        game.screen = GameScreen.GAME
    }

     if rl.GuiButton(rl.Rectangle{100, 110, WIDTH-200, 40}, "Hard") {
        game.state = nil
        game.grid_width = 30
        game.grid_height = 16
        game.mine_count = 99
        game.margin_x = MIDX - game.grid_width * CELL_SIZE / 2
        game.margin_y = MIDY - game.grid_height * CELL_SIZE / 2
        init_grid(game)
        place_mines(game)
        count_adjacent_mines(game)
        game.screen = GameScreen.GAME
    }

}