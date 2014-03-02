%%% The MIT License (MIT)
%%% 
%%% Copyright (c) 2014 Quinlan Pfiffer, Kyle Terry
%%% 
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%% 
%%% The above copyright notice and this permission notice shall be included in
%%% all copies or substantial portions of the Software.
%%% 
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%%% THE SOFTWARE.
-module(olegdb).
-include("olegdb.hrl").
-export([main/0, main/1, request_handler/1, route/2, do_accept/1]).

-define(DEFAULT_HOST, "localhost").
-define(DEFAULT_PORT, 8080).
-define(ACCEPTOR_POOL_NUM, 16).

server_manager(Caller) ->
    server_manager(Caller, ?DEFAULT_HOST, ?DEFAULT_PORT).

server_manager(Caller, Port) ->
    server_manager(Caller, ?DEFAULT_HOST, Port).

server_manager(Caller, Hostname, Port) ->
    {ok, Ip} = inet:getaddr(Hostname, inet),
    case gen_tcp:listen(Port, [binary, {ip, Ip}, {active, false}, {reuseaddr, true}, {nodelay, true}, {backlog, 50}]) of
        {ok, Sock} ->
            io:format("[-] Listening on IP ~p, port ~p~n", [Ip, Port]),
            gen_tcp:controlling_process(Sock, Caller),
            % Spawn our acceptor pool workers
            [spawn(?MODULE, do_accept, [Sock]) || _ <- lists:seq(0, ?ACCEPTOR_POOL_NUM)];
        {error, Reason} ->
            io:format("[X] Could not listen: ~p~n", [Reason])
    end.

%% Responsible for accepting new connections and spawning request handlers.
do_accept(Sock) ->
    case gen_tcp:accept(Sock) of
        {ok, Accepted} ->
            %io:format("[-] Connection accepted!~n"),
            spawn(?MODULE, request_handler, [Accepted]),
            do_accept(Sock);
        {error, Error} ->
            io:format("[X] Could not accept a connection. Error: ~p~n", [Error]);
        X -> X
    end.

request_handler(Accepted) ->
    % Read in all data, timeout after 60 seconds
    case gen_tcp:recv(Accepted, 0, 60000) of
        {ok, Data} ->
            send_handler(Data, Accepted);
        {error, closed} -> ok;
        {error, timeout} ->
            io:format("[-] Client timed out.~n"),
            ok
    end.

send_handler(Data, Accepted) ->
    Resp = route(Data, Accepted),
    case gen_tcp:send(Accepted, Resp) of
        {error, Reason} ->
            io:format("[-] Could not send to socket: ~p~n", [Reason]);
        _ -> ok
    end,
    ok = gen_tcp:close(Accepted).

route(Bits, Socket) ->
    case ol_parse:parse_http(Bits) of
        {ok, _, {Header, [send_100|_]}} ->
            hundred_handler(Header, Socket);
        {ok, ReqType, {Header, _}} ->
            case ReqType of
                get ->
                    %ol_http:not_found_response();
                    case ol_database:ol_unjar(Header) of
                        {ok, ContentType, Data} ->
                            ol_http:get_response(ContentType, Data);
                        _ -> ol_http:not_found_response()
                    end;
                post ->
                    NewHeader = ol_util:read_remaining_data(Header, Socket),
                    case ol_database:ol_jar(NewHeader) of
                        ok -> ol_http:post_response();
                        _ -> ol_http:not_found_response()
                    end;
                delete ->
                    case ol_database:ol_scoop(Header) of
                        ok -> ol_http:deleted_response();
                        _ -> ol_http:not_found_response()
                    end;
                DontKnow ->
                    ol_http:error_response(DontKnow)
            end;
        {error, ErrMsg} -> ol_http:error_response(ErrMsg)
    end.

hundred_handler(Header, Socket) ->
    case gen_tcp:send(Socket, ol_http:continue_you_shit_response()) of
        ok ->
            Data = ol_util:read_all_data(Socket, Header#ol_record.content_length),
            case ol_database:ol_jar(Header#ol_record{value=Data}) of
                ok -> ol_http:post_response();
                _ -> ol_http:not_found_response()
            end;
        {error, Reason} ->
            io:format("[-] Could not send to socket: ~p~n", [Reason])
    end.


mama() ->
    %% Eventually this function will do something interesting.
    receive
        _ -> mama()
    end.

main() -> main([]).
main(Args) ->
    io:format("[-] Starting server.~n"),
    ol_database:start(),
    case Args of
        [] -> server_manager(self());
        [Port] ->
            {PortNum, _} = string:to_integer(Port),
            server_manager(self(), PortNum);
        [Hostname, Port] ->
            {PortNum, _} = string:to_integer(Port),
            server_manager(self(), Hostname, PortNum)
    end,
    mama().
