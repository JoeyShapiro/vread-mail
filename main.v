module main

import veb
import time
import db.sqlite

const port = 8081

struct State {
mut:
	cnt int
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

	store_request(id, ctx.ip(), ctx.user_agent(), time.now().local_to_utc().format_ss_milli()) or { 
		eprintln('failed to log request: ${err}')
	}
    
    return ctx.file('footer.jpeg')
}

fn store_request(id string, ip string, user_agent string, timestamp string) ! {
	// more data is nice, but i think this is all i really need
	mut db := sqlite.connect('requests.db')!
	db.exec_param_many('INSERT INTO requests (uid, ip, user_agent, timestamp) VALUES (?, ?, ?, ?)',
		[id, ip, user_agent, timestamp])!
	db.close()!
}

fn main() {
	// could create file on fail but meh
	mut db := sqlite.connect('requests.db')!
	// orm might not make this any bigger, but dont really care
	db.exec('CREATE TABLE IF NOT EXISTS requests (id INTEGER NOT NULL PRIMARY KEY, uid TEXT NOT NULL, ip TEXT NOT NULL, user_agent TEXT NOT NULL, timestamp TEXT NOT NULL);')!
	db.close()!

	// veb.run(&App{}, port)
	mut app := &App{}
	veb.run_at[App, Context](mut app, port: port, family: .ip, timeout_in_seconds: 2) or {
		panic(err)
	}
}

@[table: 'requests']
struct Request {
	id         int    @[primary; sql: serial]
	uid        string
	ip         string
	user_agent string
	timestamp  string
}
