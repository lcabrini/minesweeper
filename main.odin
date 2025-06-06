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
MIDY :: WIDTH / 2

MARGINX :: MIDX - GRID_WIDTH * CELL_SIZE / 2
MARGINY :: 32
CELL_SIZE :: 32
GRID_WIDTH :: 16
GRID_HEIGHT :: 16
MINE_COUNT :: 40
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
    found: int,
    state: GameState,
}

main :: proc() {
    cheat := false
    if len(os.args[1:]) > 0 && os.args[1] == "cheat" {
        cheat = true
    }

    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WIDTH, HEIGHT, TITLE)
    rl.SetTargetFPS(60)

    exploded_tex := rl.LoadTexture("exploded.png")
    flag_tex := rl.LoadTexture("flag.png")
    incorrect_tex := rl.LoadTexture("incorrect.png")
    maybe_tex := rl.LoadTexture("maybe.png")
    mine_tex := rl.LoadTexture("mine.png")

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

    grid: [dynamic]Cell
    init_grid(&grid, GRID_WIDTH, GRID_HEIGHT)
    place_mines(&grid, GRID_WIDTH, GRID_HEIGHT, MINE_COUNT)
    count_adjacent_mines(&grid)

    game := Game{}
    start_time := time.now()
    seconds: f64

    for !rl.WindowShouldClose() {
        if game.state == .STARTED && rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
            cell := get_mouse_cell(&grid)
            if cell != nil && cell.x >= 0 && cell.x < GRID_WIDTH && cell.y >= 0 && cell.y < GRID_HEIGHT {
                if cell.has_mine {
                    cell.exploded = true
                    game.state = .LOST
                } else if cell.adjacent_mines > 0 {
                    cell.opened = true
                } else {
                    open_cells(&game, &grid, cell.y, cell.x)
                }

                if grid_complete(&grid) do game.state = .WON
            }
        }

        if game.state == .STARTED && rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) {
            cell := get_mouse_cell(&grid)
            if cell != nil {
                if !cell.opened {
                    switch cell.flag {
                        case .NONE:
                            if game.found < MINE_COUNT {
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

           if grid_complete(&grid) do game.state = .WON
        }

        if game.state == .STARTED {
            now := time.now()
            duration := time.diff(start_time, now)
            seconds = time.duration_seconds(duration)
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        draw_grid(GRID_WIDTH, GRID_HEIGHT)

        for cell in grid {
            if cheat && cell.has_mine {
                x := cell.x * CELL_SIZE + MARGINX + 1
                y := cell.y * CELL_SIZE + MARGINY + 1
                w: i32 = CELL_SIZE - 2
                h: i32 = CELL_SIZE - 2
                rl.DrawRectangle(x, y, h, w, rl.DARKGRAY)
            } else if cell.opened && cell.adjacent_mines > 0 {
                s := strings.clone_to_cstring(fmt.tprint(cell.adjacent_mines))
                tw := rl.MeasureText(s, COUNTER_SIZE)
                x := MARGINX + cell.x * CELL_SIZE + (CELL_SIZE / 2 - tw / 2)
                y := MARGINY + cell.y * CELL_SIZE + (CELL_SIZE / 2 - COUNTER_SIZE / 2)
                rl.DrawText(s, x, y, COUNTER_SIZE, counter_colors[cell.adjacent_mines])
            } else if !cell.opened {
                x := MARGINX + cell.x * CELL_SIZE + 1
                y := MARGINY + cell.y * CELL_SIZE + 1
                h := i32(CELL_SIZE - 2)
                w := i32(CELL_SIZE - 2)
                rl.DrawRectangle(x, y, w, h, rl.GRAY)
            }

            #partial switch cell.flag {
                case .FLAG:
                    x := MARGINX + cell.x * CELL_SIZE + 1
                    y := MARGINY + cell.y * CELL_SIZE + 1
                    rl.DrawTexture(flag_tex, x, y, rl.RAYWHITE)
                case .MAYBE:
                    x := MARGINX + cell.x * CELL_SIZE + 1
                    y := MARGINY + cell.y * CELL_SIZE + 1
                    rl.DrawTexture(maybe_tex, x, y, rl.RAYWHITE)
            }

            if cell.exploded {
                x := MARGINX + cell.x * CELL_SIZE + 1
                y := MARGINY + cell.y * CELL_SIZE + 1
                rl.DrawTexture(exploded_tex, x, y, rl.RAYWHITE)
            }
        }

        rl.DrawRectangle(0, HEIGHT - 30, WIDTH, HEIGHT - 30, rl.BLUE)
        stats := rl.TextFormat("%d of %d mines found", game.found, MINE_COUNT)
        rl.DrawText(stats, 100, HEIGHT - 25, 20, rl.RAYWHITE)

        play_time := rl.TextFormat("Time: %.1f", seconds)
        rl.DrawText(play_time, 700, HEIGHT - 25, 20, rl.RAYWHITE)
        rl.EndDrawing()
    }

    rl.UnloadTexture(exploded_tex)
    rl.UnloadTexture(flag_tex)
    rl.UnloadTexture(incorrect_tex)
    rl.UnloadTexture(maybe_tex)
    rl.UnloadTexture(mine_tex)
    rl.CloseWindow()
}

init_grid :: proc(grid: ^[dynamic]Cell, w, h: i32) {
    for r in 0..<h {
        for c in 0..<w {
            cell := Cell{}
            cell.x = c
            cell.y = r
            append(grid, cell)
        }
    }
}

draw_grid :: proc(w, h: i32) {
    for r: i32 = 0; r <= h; r += 1 {
        rl.DrawLine(MARGINX, r*CELL_SIZE+MARGINY, w*CELL_SIZE+MARGINX, r*CELL_SIZE+MARGINY, rl.RAYWHITE)
    }

    for c: i32 = 0; c <= w; c += 1 {
        rl.DrawLine(c*CELL_SIZE+MARGINX, MARGINY, c*CELL_SIZE+MARGINX, h*CELL_SIZE+MARGINY, rl.RAYWHITE)
    }
}

get_mouse_cell :: proc(grid: ^[dynamic]Cell) -> ^Cell {
    mp := rl.GetMousePosition()
    x := mp.x >= MARGINX ? i32((mp.x - MARGINX) / CELL_SIZE) : -1
    y := mp.y >= MARGINY ? i32((mp.y - MARGINY) / CELL_SIZE) : -1

    for &cell in grid {
        if x == cell.x && y == cell.y {
            return &cell
        }
    }

    return nil
}

place_mines :: proc(grid: ^[dynamic]Cell, w, h: i32, count: int) {
    placed := 0
    outer: for {
        x := rl.GetRandomValue(0, w-1)
        y := rl.GetRandomValue(0, h-1)

        for &cell in grid {
            if cell.x == x && cell.y == y {
                if cell.has_mine do continue outer

                cell.has_mine = true
                placed += 1
                break
            }
        }

        if placed >= count do return
    }
}

count_adjacent_mines :: proc(grid: ^[dynamic]Cell) {
    for i := 0; i < len(grid); i += 1 {
        cell := &grid[i]
        if !cell.has_mine {
            count: i32 = 0
            if cell.y - 1 >= 0 {
                if cell.x - 1 >= 0 && grid[i-GRID_WIDTH-1].has_mine do count += 1
                if grid[i-GRID_WIDTH].has_mine do count += 1
                if cell.x + 1 < GRID_WIDTH && grid[i-GRID_WIDTH+1].has_mine do count += 1
            }

            if cell.x - 1 >= 0 && grid[i-1].has_mine do count += 1
            if cell.x + 1 < GRID_WIDTH && grid[i+1].has_mine do count += 1

            if cell.y + 1 < GRID_HEIGHT {
                if cell.x - 1 >= 0 && grid[i+GRID_WIDTH-1].has_mine do count += 1
                if grid[i+GRID_WIDTH].has_mine do count += 1
                if cell.x + 1 < GRID_WIDTH && grid[i+GRID_WIDTH+1].has_mine do count += 1
            }

            cell.adjacent_mines = count
        }
    }
}

open_cells :: proc(game: ^Game, grid: ^[dynamic]Cell, row, col: i32) {
    idx := row * GRID_WIDTH + col

    if row < 0 || row >= GRID_HEIGHT || col < 0 || col >= GRID_WIDTH {
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