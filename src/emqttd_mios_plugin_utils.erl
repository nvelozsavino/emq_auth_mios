%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2016, MiOS Ltd.
%%% @doc
%%%
%%% @end
%%% Created : 14. Sep 2016 12:32 PM
%%%-------------------------------------------------------------------
-module(emqttd_mios_plugin_utils).
-author("nico").


-define(EMPTY(Variable), (Variable=:= undefined orelse Variable=:= <<>>)).

%% API
-export([check_auth/4, delete_client/1,check_acl/3,create_tables/0,delete_tables/0, load_key/1, update_all_clients/0]).

get_json(Json) ->
  try
    Decoded = jiffy:decode(Json,[return_maps]),
      io:format("Deocoded: ~p~n",[Decoded]),
      Decoded
  catch
    error:Error -> throw({invalid_json,Error})
  end.

decode_base64(Base64) ->
  try base64:decode(Base64)
  catch
    error:_ -> throw(invalidBase64)
  end.


verify_signature(Identity, _,_) when ?EMPTY(Identity)->
  throw(identity_undefined);
verify_signature(_, IdentitySignature,_) when ?EMPTY(IdentitySignature)->
  throw(signature_undefined);
verify_signature(_, _,PubKey) when ?EMPTY(PubKey)->
  throw(public_key_undefined);
verify_signature(Identity, IdentitySignature,PubKey) ->
  try
    Signature =decode_base64(IdentitySignature),
    public_key:verify(Identity,sha512,Signature,PubKey)
  catch
    throw:_ ->false
  end.


to_string(Number)->
  lists:flatten(io_lib:format("~p", [Number])).

get_white_list([H|L]) ->
  PK_PermExist=maps:is_key(<<"PK_Permission">>,H),
  if
    PK_PermExist ->
      PK_PermNum = maps:get(<<"PK_Permission">>,H),
      PK_Perm41=PK_PermNum==41,
      if
        PK_Perm41 ->
          ArgumentExist=maps:is_key(<<"Arguments">>,H),
          if
            ArgumentExist ->
              maps:get(<<"Arguments">>,H);
            true -> all
          end;
        true ->
          get_white_list(L)
      end;
    true ->
      get_white_list(L)
  end;
get_white_list([])-> all.


%%find_white_list([H|L]) ->
%%  find_white_list(L).
%%find_white_list(Perm) ->
%%  PermExist = maps:is_key(<<"PK_Permission">>,Perm),
%%  if
%%    PermExist ->
%%      PermNumber=maps:is_key(<<"PK_Permission">>,Perm),
%%  end,
%%  if
%%    maps:get(<<"PK_Permission">>,Perm)==41 ->
%%      maps:get(<<"Arguments">>,Perm);
%%    true ->
%%  end


get_token_type(IdentityJson) when ?EMPTY(IdentityJson) ->
  throw(identity_undefined);
get_token_type(IdentityJson) ->
  Account =maps:is_key(<<"PK_Account">>,IdentityJson),
  if
    Account ->
      DeviceExist =maps:is_key(<<"PK_Device">>,IdentityJson),
      UserExist =maps:is_key(<<"PK_User">>,IdentityJson) and
        maps:is_key(<<"PK_Server_Auth">>,IdentityJson) and
        maps:is_key(<<"Seq">>,IdentityJson) and
        maps:is_key(<<"Generated">>,IdentityJson) and
        maps:is_key(<<"Username">>,IdentityJson),

      if
        DeviceExist ->
          io:format("It's a device token~n"),
          PK_Account=maps:get(<<"PK_Account">>,IdentityJson),
          PK_Device=maps:get(<<"PK_Device">>,IdentityJson),
          {device,PK_Account,PK_Device};
        UserExist ->
          io:format("It's a user token~n"),
          PK_User=maps:get(<<"PK_User">>,IdentityJson),
          PK_Server_Auth=maps:get(<<"PK_Server_Auth">>,IdentityJson),
          Seq=maps:get(<<"Seq">>,IdentityJson),
          Generated=maps:get(<<"Generated">>,IdentityJson),
          Client_Id=to_string(PK_User) ++
          "_" ++ to_string(PK_Server_Auth) ++
          "_" ++ to_string(Seq) ++
          "_" ++ to_string(Generated),
          io:format("ClientId ~p~n",[Client_Id]),
          PK_Account=maps:get(<<"PK_Account">>,IdentityJson),
          Username = binary_to_list(maps:get(<<"Username">>,IdentityJson)),
          PermissionsExist=maps:is_key(<<"Permissions">>,IdentityJson),
          if
            PermissionsExist ->
              io:format("Permissions exist~n"),
              Permissions = maps:get(<<"Permissions">>,IdentityJson),
              {user, PK_Account,Client_Id,Username,get_white_list(Permissions)};
            true->
              {user, PK_Account,Client_Id,Username,all}
          end;


        true-> throw(invalid_token)
      end;
    true-> throw(invalid_token)
  end.


check_auth(PublicKey,_,_,_) when ?EMPTY(PublicKey)->
  {error,public_key_undefined};
check_auth(_,UserName,_,_) when ?EMPTY(UserName)->
  {error,username_undefined};
check_auth(_,_,Password,_) when ?EMPTY(Password)->
  {error,password_undefined};
check_auth(_,_,_,ClientId) when ?EMPTY(ClientId)->
  {error,client_id_undefined};
check_auth(PublicKey,UserName,Password,ClientId) ->
  io:format("ClientID: ~p~nUsername: ~p~nPassword: ~p~n",[ClientId,UserName,Password]),
  try
    JsonToken = get_json(Password),
    case maps:is_key(<<"Identity">>,JsonToken) and maps:is_key(<<"IdentitySignature">>,JsonToken) of
      true ->
        Identity=maps:get(<<"Identity">>,JsonToken),
        IdentitySignature=maps:get(<<"IdentitySignature">>,JsonToken),
        SignatureVerified = (PublicKey == no_verify) orelse (verify_signature(Identity,IdentitySignature,PublicKey)),
          if
            SignatureVerified ->
              IdentityDecoded = decode_base64(Identity),
              IdentityJson = get_json(IdentityDecoded),
              case get_token_type(IdentityJson) of
                {user,PK_Account,TokenClientId,TokenUsername,WhiteList} ->
                  Authorized = (UserName == TokenUsername) and (TokenClientId==ClientId),
                  io:format("UserName: ~p  Username: ~p~n",[TokenUsername,UserName]),
                  if
                    Authorized ->
                      register_user(PK_Account,ClientId,WhiteList),
                      update_clients(PK_Account),
                      io:format("Done with user ~p~n-----------------------~n",[ClientId]),
                      ok;
                    true->
                      {error,not_authorized}
                  end;
                {device,PK_Account,PK_Device} ->
                  PK_DeviceStr=to_string(PK_Device),
                  Authorized = (UserName == PK_DeviceStr) and (PK_DeviceStr==ClientId),
                  io:format("PK_Device: ~p  Username: ~p~n",[PK_DeviceStr,UserName]),
                  if
                    Authorized ->
                      register_device(PK_Account,PK_Device),
                      update_clients(PK_Account),
                      io:format("Done with device ~p~n-----------------------~n",[PK_Device]),
                      ok;
                    true->
                      {error,not_authorized}
                  end;
                _Else ->
                  io:format("Unrecognized TokenType ~p~n",[_Else]),
                  {error,unrecongized_token}
              end;
            true ->
              io:format("Signature Failed ~n"),
              {error,signature_failed}
          end;
      false ->
        io:format("Token unrecognized ~n"),
        {error,token_unrecognized}
    end
  catch
    throw:Error ->
      io:format("Throw ~p~n",[Error]),
      {error,Error}
  end.


register_device(PK_Account,PK_Device) ->
  create_table(devices,bag),
  io:format("Device ~p inserted~n",[PK_Device]),
  ets:insert(devices,{PK_Account,PK_Device}),
  create_table(clients,set),
  ets:insert(clients,{to_string(PK_Device),device,{PK_Account,PK_Device}}).
register_user(PK_Account,ClientId,WhiteList) ->
  create_table(users,bag),
  io:format("User ~p inserted~n",[ClientId]),
  ets:insert(users,{PK_Account,ClientId,WhiteList}),
  create_table(clients,set),
  ets:insert(clients,{ClientId,user,{PK_Account,ClientId}}).

ets_lookup(Table,Key) ->
  TableNotExist=(ets:info(Table)==undefined),
  if
    TableNotExist -> [];
    true->
      ets:lookup(Table,Key)
  end.

update_clients(PK_Account) ->
  Devices = ets_lookup(devices,PK_Account),
%%  io:format("update_clients: Devices: ~p~n",[Devices]),
  Users = ets_lookup(users,PK_Account),
%%  io:format("update_clients: Users: ~p~n",[Users]),
  update_users_topics(Users,Devices),
  update_device_topics(Devices,Users).

list_contains(Element,[H|L])->
  Exist = (Element == H),
  if
    Exist->
      true;
    true->
      list_contains(Element,L)
  end;
list_contains(_,[])-> false.


insert_topics(Sub,Pub,Topics)->
  {OldSubTopic,OldPubTopics}=Topics,
  {OldSubTopic++Sub,OldPubTopics++Pub}.


get_user_topics(ClientId,DeviceList,WhiteList)->
  get_user_topics(ClientId,DeviceList,{[],[]},WhiteList).

get_user_topics(ClientId,[H|T],Topics,WhiteList)->
  {_,PK_Device}=H,
  Update = (WhiteList == all) orelse (list_contains(PK_Device,WhiteList)),
  if
    Update ->
      NewSubTopics = [
%%        to_string(PK_Device)++"/connected",
        to_string(PK_Device)++"/"++ClientId++"/out",
        to_string(PK_Device)++"/"++ClientId++"/ud"],
      NewPubTopics = [
        to_string(PK_Device)++"/"++ClientId++"/in",
        to_string(PK_Device)++"/"++ClientId++"/alive"],

      NewTopics=insert_topics(NewSubTopics,NewPubTopics,Topics),
      get_user_topics(ClientId,T,NewTopics,WhiteList);
    true ->
      get_user_topics(ClientId,T,Topics,WhiteList)
  end;
get_user_topics(ClientId,[],Topics,_)->
  Pub=[ClientId++"/connected"],
  Sub=["+/connected"],
  NewTopics=insert_topics(Sub,Pub,Topics),
%%  io:format("get_user_topics: ~p Ending with topics: ~p~n",[ClientId,NewTopics]),
  NewTopics.



get_device_topics(PK_Device,UsersList)->
  get_device_topics(PK_Device,UsersList,{[],[]}).

get_device_topics(PK_Device,[H|T],Topics)->
  {_,ClientId,WhiteList}=H,
  Update = (WhiteList == all) orelse (list_contains(PK_Device,WhiteList)),
  if
    Update ->
      NewPubTopics = [
          to_string(PK_Device)++"/"++ClientId++"/out",
          to_string(PK_Device)++"/"++ClientId++"/source",
          to_string(PK_Device)++"/"++ClientId++"/ud"],
      NewSubTopics = [
          to_string(PK_Device)++"/"++ClientId++"/in",
          to_string(PK_Device)++"/"++ClientId++"/source",
          to_string(PK_Device)++"/"++ClientId++"/alive"],
%%          ClientId++"/connected"],
%%      io:format("get_device_topics: Topics: ~p~n",[Topics]),
      NewTopics=insert_topics(NewSubTopics,NewPubTopics,Topics),
      get_device_topics(PK_Device,T,NewTopics);
    true ->
      get_device_topics(PK_Device,T,Topics)
  end;
get_device_topics(PK_Device,[],Topics)->
  Pub=[to_string(PK_Device)++"/connected"],
  Sub=["+/connected"],
  NewTopics= insert_topics(Sub,Pub,Topics),
%%  io:format("get_device_topics: ~p Ending with topics: ~p~n",[PK_Device,NewTopics]),
  NewTopics.



update_users_topics([H|L],DeviceList)->
  {_,ClientId,WhiteList}=H,
  NewTopics=get_user_topics(ClientId,DeviceList,WhiteList),
  create_table(topics,set),
  ets:insert(topics,{ClientId,NewTopics}),
  io:format("update_users_topics: Topics for ~p are: ~p~n",[ClientId,NewTopics]),
  update_users_topics(L,DeviceList);
update_users_topics([],_)-> none.

update_device_topics([H|L],UserList)->
  {_,PK_Device}=H,
  NewTopics=get_device_topics(PK_Device,UserList),
  create_table(topics,set),
  ets:insert(topics,{to_string(PK_Device),NewTopics}),
  io:format("update_device_topics: Topics for ~p are: ~p~n",[PK_Device,NewTopics]),
  update_device_topics(L,UserList);
update_device_topics([],_)-> none.

create_table(Name,Type) ->
  TableNotExist = (ets:info(Name)==undefined),
  if
    TableNotExist ->
      ets:new(Name,[Type,named_table]);
    true->ok
  end.

delete_table(Name) ->
  TableNotExist = (ets:info(Name)==undefined),
  if
    TableNotExist -> ok;
    true->
      ets:delete(Name)
  end.

delete_client(Client) ->
  TableNotExist = (ets:info(clients)==undefined),
  if
    TableNotExist->
      ok;
    true->
      Info= ets_lookup(clients,Client),
      InfoLen=length(Info),
      if
        InfoLen==1 ->
          [Element]=Info,
          {_,Type,Data}=Element,
          ets:match_delete(clients,Element),
          delete_topic(Client),
          case Type of
            user ->
              {PK_Account,ClientId}=Data,
              delete_user(PK_Account,ClientId),
              io:format("Deleting user: ~p~n",[ClientId]),
              update_clients(PK_Account);
            device->
              {PK_Account,PK_Device}=Data,
              delete_device(PK_Account,PK_Device),
              io:format("Deleting device: ~p~n",[PK_Device]),
              update_clients(PK_Account)
          end;
        true->
          io:format("Client: ~p does not exist~n",[Client]),
          ok
      end
  end.


delete_topic(Client)->
  TableNotExist = (ets:info(topics)==undefined),
  if
    TableNotExist -> ok;
    true -> ets:match_delete(topics,{Client,'_'})
  end.

delete_user(PK_Account,ClientId)->
  TableNotExist = (ets:info(users)==undefined),
  if
    TableNotExist -> ok;
    true -> ets:match_delete(users,{PK_Account,ClientId,'_'})
  end.

delete_device(PK_Account,PK_Device)->
  TableNotExist = (ets:info(devices)==undefined),
  if
    TableNotExist -> ok;
    true -> ets:match_delete(devices,{PK_Account,PK_Device})
  end.

clean_topic(Topic)->
  Pos=string:chr(Topic,$#),
  if
    Pos==0 ->
      Topic;
    true ->
      string:substr(Topic,1,Pos)
  end.


topic_match_splited([H1|T1],[H2|T2])->
  if
    H1==H2 orelse H2=="+" -> topic_match_splited(T1,T2);
    true->false
  end;
topic_match_splited([_H1|_T1],[])-> false;
topic_match_splited([],[_H2|_T2])-> false;
topic_match_splited([],[])-> true.



topic_match_one(RequiredTopic,RulesTopic)->
  CleanedTopic=clean_topic(RequiredTopic),
  SplitedRequired=string:tokens(CleanedTopic,"/"),
  SplitedRules=string:tokens(RulesTopic,"/"),
  if
    length(SplitedRequired)>length(SplitedRules)-> false;
    true -> topic_match_splited(SplitedRequired,SplitedRules)
  end.

topic_match(Topic,[H|T])->
  Match = topic_match_one(Topic,H),
  if
    Match -> true;
    true-> topic_match(Topic,T)
  end;
topic_match(_Topic,[])->false.



check_acl(ClientId,PubSub,Topic)->
  io:format("check_acl ClientId: ~p, Pub: ~p, Topic: ~p~n",[ClientId,PubSub,Topic]),
  Topics=ets_lookup(topics,ClientId),
  io:format("Topics: ~p~n",[Topics]),
  if
    length(Topics)==1 ->
      [{_ClientId,{Sub,Pub}}]=Topics,
      case PubSub of
        publish->
          topic_match(Topic,Pub);
        subscribe->
          topic_match(Topic,Sub);
        _Else ->
          io:format("Unrecongnized event~n"),
          false
      end;
    true->
      false
  end.

create_tables()->
  create_table(devices,bag),
  create_table(users,bag),
  create_table(clients,set),
  create_table(topics,set).

delete_tables()->
  delete_table(devices),
  delete_table(users),
  delete_table(clients),
  delete_table(topics).


load_key(Filename) ->
  {ok, Pem} = file:read_file(Filename),
  [Entry] = public_key:pem_decode(Pem),
  Cert=public_key:pem_entry_decode(Entry),
  Cert.


keys(TableName) ->
  FirstKey = ets:first(TableName),
  keys(TableName, FirstKey, [FirstKey]).

keys(_TableName, '$end_of_table', ['$end_of_table'|Acc]) ->
  Acc;
keys(TableName, CurrentKey, Acc) ->
  NextKey = ets:next(TableName, CurrentKey),
  keys(TableName, NextKey, [NextKey|Acc]).


update_all_clients() ->
  KeysSet = sets:from_list(keys(users)++keys(devices)),
  update_all_clients(KeysSet).
update_all_clients([H|T])->
  update_clients(H),
  update_all_clients(T);
update_all_clients([])->
  ok.