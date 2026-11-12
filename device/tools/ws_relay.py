"""윈도우 앱 → 맥(0.0.0.0:8766) → adb forward(127.0.0.1:8765) → 보드 신호 서버.
보드가 집 공유기에 없을 때 사용. 먼저 start_board.sh 실행."""
import socket, sys, threading

LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8766
TARGET = ("127.0.0.1", 8765)

def pipe(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        for s in (src, dst):
            try:
                s.close()
            except OSError:
                pass

def main():
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", LISTEN_PORT))
    srv.listen()
    print(f"중계 0.0.0.0:{LISTEN_PORT} -> {TARGET[0]}:{TARGET[1]} (Ctrl+C로 끔)")
    while True:
        client, addr = srv.accept()
        try:
            upstream = socket.create_connection(TARGET, timeout=3)
            upstream.settimeout(None)
        except OSError as e:
            print(f"  {addr[0]} 연결했지만 보드 8765에 못 붙음: {e} → start_board.sh 확인")
            client.close()
            continue
        print(f"  연결: {addr[0]}")
        threading.Thread(target=pipe, args=(client, upstream), daemon=True).start()
        threading.Thread(target=pipe, args=(upstream, client), daemon=True).start()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n중계 끔")
