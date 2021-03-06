%%
%% Erlang Redis client
%%
%% Usage:
%%   {ok, Client} = eredis:start_link().
%%   {ok, <<"OK">>} = eredis:q(["SET", "foo", "bar"]).
%%   {ok, <<"bar">>} = eredis:q(["GET", "foo"]).

-module(eredis).
-author('knut.nesheim@wooga.com').

-include("eredis.hrl").

-export([start_link/0, start_link/2, start_link/3, start_link/4,
         q/2]).

%% Exported for testing
-export([create_multibulk/1]).

%%
%% PUBLIC API
%%

-spec start_link() -> {ok, Client::pid()} |
                          {error, {connection_error, Reason::any()}}.
start_link() ->
    start_link("127.0.0.1", 6379, 0, "").

start_link(Host, Port) ->
    start_link(Host, Port, 0, "").

start_link(Host, Port, Database) ->
    start_link(Host, Port, Database, "").

start_link(Host, Port,  Database, Password) when is_list(Host);
                                                 is_integer(Port);
                                                 is_integer(Database);
                                                 is_list(Password) ->
    eredis_client:start_link(Host, Port, Database, Password).


-spec q(Client::pid(), Command::iolist()) ->
               {ok, Value::binary()} | {error, Reason::binary()}.
%% @doc: Executes the given command in the specified connection. The
%% command must be a valid Redis command and may contain arbitrary
%% data which will be converted to binaries. The returned values will
%% always be binaries.
q(Client, Command) ->
    call(Client, Command).


%%
%% INTERNAL HELPERS%%

call(Client, Command) ->
    Request = {request, create_multibulk(Command)},
    gen_server:call(Client, Request).

-spec create_multibulk(Args::iolist()) -> Command::iolist().
%% @doc: Creates a multibulk command with all the correct size headers
create_multibulk(Args) ->
    ArgCount = [<<$*>>, integer_to_list(length(Args)), <<?NL>>],
    ArgsBin = lists:map(fun to_bulk/1, lists:map(fun to_binary/1, Args)),

    [ArgCount, ArgsBin].

to_bulk(B) when is_binary(B) ->
    [<<$$>>, integer_to_list(iolist_size(B)), <<?NL>>, B, <<?NL>>].

%% @doc: Convert given value to binary. Fallbacks to
%% term_to_binary/1. For floats, throws {cannot_store_floats, Float}
%% as we do not want floats to be stored in Redis. Your future self
%% will thank you for this.
to_binary(X) when is_list(X)    -> list_to_binary(X);
to_binary(X) when is_atom(X)    -> list_to_binary(atom_to_list(X));
to_binary(X) when is_binary(X)  -> X;
to_binary(X) when is_integer(X) -> list_to_binary(integer_to_list(X));
to_binary(X) when is_float(X)   -> throw({cannot_store_floats, X});
to_binary(X)                    -> term_to_binary(X).

