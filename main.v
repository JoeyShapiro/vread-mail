module main

import veb
import rand

const port = 8080

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
    user_name := ctx.query['name'] or {
        // we can exit early and send a different response if no `name` parameter was passed
        return ctx.text('no user was found')
    }
    
    return ctx.file('footer.jpeg')
}

fn main() {
	println('veb example')
	// veb.run(&App{}, port)
	mut app := &App{}
	veb.run_at[App, Context](mut app, port: port, family: .ip, timeout_in_seconds: 2) or {
		panic(err)
	}
}