use std::{
    env,
    fmt::Write as _,
    io::Write,
    net::{SocketAddr, TcpListener, TcpStream},
};

const MYIP_LISTEN_V4: &str = "MYIP_LISTEN_V4";
const MYIP_LISTEN_V6: &str = "MYIP_LISTEN_V6";
const MYIP_HUMANE: &str = "MYIP_HUMANE";

const MYIP_MODE: &str = "MYIP_MODE";

enum Mode {
    Dontwait,
    WriteAll,
}

fn write(mode: Mode) -> impl Fn(TcpStream, &[u8], &mut String) {
    move |mut stream, buf, error| {
        error.clear();

        let io_error = match mode {
            Mode::Dontwait => match stream.write(buf) {
                Ok(wrote) if wrote != buf.len() => {
                    _ = write!(
                        error,
                        "failed to write whole buffer: wrote {wrote}B / {}B",
                        buf.len()
                    );
                    None
                }
                Ok(..) => None,
                Err(e) => Some(e),
            },
            Mode::WriteAll => stream.write_all(buf).err(),
        };

        if let Some(io_error) = io_error {
            _ = write!(error, "IO error: {io_error}");
        }
    }
}

fn listen(listener: TcpListener, finalize: impl Fn(&mut String, TcpStream, SocketAddr)) {
    let mut error_buffer = String::new();

    for stream in listener.incoming() {
        let stream = stream.expect("listener became invalid");
        let Ok(addr) = stream.peer_addr() else {
            continue;
        };

        finalize(&mut error_buffer, stream, addr);
        if !error_buffer.is_empty() {
            eprintln!("failed to report address {addr}: {error_buffer}");
        }
    }
}

fn main() {
    let listen_v4 = env::var(MYIP_LISTEN_V4).map_or(None, |x| match x.as_str() {
        "none" => None,
        some => Some(
            some.parse()
                .unwrap_or_else(|e| panic!("invalid {MYIP_LISTEN_V4}: {e}")),
        ),
    });
    let listen_v6 = env::var(MYIP_LISTEN_V6).map_or(None, |x| match x.as_str() {
        "none" => None,
        some => Some(
            some.parse()
                .unwrap_or_else(|e| panic!("invalid {MYIP_LISTEN_V6}: {e}")),
        ),
    });
    let mode = env::var(MYIP_MODE).map_or(Mode::Dontwait, |e| match e.as_str() {
        "dontwait" => Mode::Dontwait,
        "writeall" => Mode::WriteAll,
        _ => panic!("{MYIP_MODE} must be \"dontwait\" or \"writeall\" (default: \"dontwait\")"),
    });
    let humane = env::var(MYIP_HUMANE).map_or(true, |e| match e.as_str() {
        "0" | "false" | "no" => false,
        "1" | "true" | "yes" => true,
        _ => panic!("invalid {MYIP_HUMANE}, expected one of: 0, false, no, 1, true, yes"),
    });

    let listen_on: SocketAddr = match (listen_v4, listen_v6) {
        (Some(..), Some(..)) => {
            panic!("setting both {MYIP_LISTEN_V4} and {MYIP_LISTEN_V6} is not supported")
        }
        (None, None) => {
            panic!("it's required to set {MYIP_LISTEN_V4} or {MYIP_LISTEN_V6}")
        }
        (Some(v4), None) => v4,
        (None, Some(v6)) => v6,
    };

    let listener = TcpListener::bind(listen_on)
        .unwrap_or_else(|e| panic!("failed to bind on {listen_on}: {e}"));
    let addr = listener
        .local_addr()
        .expect("failed to get listening address");

    println!("listening on {addr}");

    let write = write(mode);
    listen(listener, |eb, stream, sa| {
        if humane {
            write(stream, sa.ip().to_string().as_bytes(), eb)
        } else {
            match sa {
                SocketAddr::V4(v4) => write(stream, &v4.ip().octets(), eb),
                SocketAddr::V6(v6) => write(stream, &v6.ip().octets(), eb),
            }
        }
    });
}
