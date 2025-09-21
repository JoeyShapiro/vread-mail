module main

import veb
import time
import db.sqlite
import os

const port = 8081

struct State {
mut:
	key string
}

pub struct App {
mut:
	state shared State
}

struct Context {
	veb.Context
}

pub fn (app &App) before_request() {
	$if trace_before_request ? {
		eprintln('[veb] before_request: ${app.req.method} ${app.req.url}')
	}
}

@['/'; get]
pub fn (app &App) get_footer(mut ctx Context) veb.Result {
    id := ctx.query['id'] or { "0" }
	mode := ctx.query['theme'] or { "unknown" }

	// sadly cant get exact aspect ratio unless i use js. or do every possible combination
	// maybe there is some way to determine screen size or device
	store_request(id, ctx.ip(), ctx.user_agent(), mode, time.now().local_to_utc().format_ss_milli()) or {
		eprintln('failed to log request: ${err}')
	}
    
    return ctx.file('footer.jpeg')
}

fn store_request(id string, ip string, user_agent string, mode string, timestamp string) ! {
	// more data is nice, but i think this is all i really need
	mut db := sqlite.connect('requests.db')!
	db.exec_param_many('INSERT INTO requests (uid, ip, user_agent, mode, timestamp) VALUES (?, ?, ?, ?, ?)',
		[id, ip, user_agent, mode, timestamp])!
	db.close()!
}

@['/read'; get]
pub fn (app &App) read_requests(mut ctx Context) veb.Result {
	id := ctx.query['id'] or {
		return ctx.not_found()
	}
	key := ctx.query['key'] or { "" }

	if key != app.state.key {
		return ctx.not_found()
	}

	rows := get_request(id) or {
		return ctx.text('failed to get requests for id=${id}: ${err}')
	}

	mut result := 'Requests for id=${id}:\n\n'
	for row in rows {
		result += 'IP: ${row.vals[0]}\nUser-Agent: ${row.vals[1]}\nTimestamp: ${row.vals[2]}\n\n'
	}
	return ctx.text(result)
}

fn get_request(id string) ![]sqlite.Row {
	mut db := sqlite.connect('requests.db')!
	mut rows := db.exec_param('SELECT ip, user_agent, mode, timestamp FROM requests WHERE uid = ?', id)!
	db.close()!
	return rows
}

fn main() {
	// could create file on fail but meh
	mut db := sqlite.connect('requests.db')!
	// orm might not make this any bigger, but dont really care
	db.exec('CREATE TABLE IF NOT EXISTS requests (id INTEGER NOT NULL PRIMARY KEY, uid TEXT NOT NULL, ip TEXT NOT NULL, user_agent TEXT NOT NULL, mode TEXT NOT NULL, timestamp TEXT NOT NULL);')!
	db.close()!

	// veb.run(&App{}, port)
	mut app := &App{}
	lock app.state {
		key := os.getenv('KEY')
		if key == '' {
			eprintln('KEY environment variable is not set')
			return
		}

		app.state = State{ key }
	}

	veb.run_at[App, Context](mut app, port: port, family: .ip, timeout_in_seconds: 2) or {
		panic(err)
	}
}
