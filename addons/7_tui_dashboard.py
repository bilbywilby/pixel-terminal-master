import curses, sqlite3
def main(stdscr):
    stdscr.addstr(0, 0, "DAG State Monitor - Active")
    stdscr.refresh()
    stdscr.getkey()
curses.wrapper(main)
