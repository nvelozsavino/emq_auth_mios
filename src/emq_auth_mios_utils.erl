%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2016, MiOS Ltd.
%%% @doc
%%%
%%% @end
%%% Created : 14. Sep 2016 12:32 PM
%%%-------------------------------------------------------------------
-module(emq_auth_mios_utils).
-author("nico").
-include("emq_auth_mios.hrl").


-define(EMPTY(Variable), (Variable=:= undefined orelse Variable=:= <<>>)).

%% API
-export([check_auth/4, delete_client/1,check_acl/3,create_tables/0,delete_tables/0, load_key/1, update_all_clients/0]).

get_json(Json) ->
  try
    jiffy:decode(Json,[return_maps])
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
intstr_list_to_list(StrList)->
  intstr_list_to_list(StrList,[]).
intstr_list_to_list([H|T],List) ->
  {Number,_Rest}=string:to_integer(H),
  case Number of
    error ->
      ?LOG_LV(?LV_ERROR,"error, no number ~p~n",[H]),
      error;
    Num->
      intstr_list_to_list(T,[Num]++List)
  end;
intstr_list_to_list([],List)->
  List.

bin_to_list(Binary)->
  if
    is_binary(Binary) ->
      binary_to_list(Binary);
    true-> Binary
  end.

process_white_list(WhiteListString)->
%%  ?LOG_LV(?LV_STATUS,"No process_white_list~p~n",[WhiteListString]),
  IsString=io_lib:printable_list(WhiteListString),
  if
    IsString->
%%      ?LOG_LV(?LV_STATUS,"Is String~n"),
      {Match,Matches}=re:run(WhiteListString,"^\\[(.*)\\]$"),
%%      ?LOG_LV(?LV_STATUS,"Match found? ~p,~p~n",[Match,Matches]),
      case Match of
        match ->
          MatchesLen=length(Matches),
          if
            MatchesLen==2 ->
%%              ?LOG_LV(?LV_STATUS,"Matches length =~p~n",[MatchesLen]),
              Indexes=tuple_to_list(lists:nth(2,Matches)),
%%              ?LOG_LV(?LV_STATUS,"Indexes =~p~n",[Indexes]),
              Start=lists:nth(1,Indexes)+1,
%%              ?LOG_LV(?LV_STATUS,"Start =~p~n",[Start]),
              End=lists:nth(2,Indexes),
%%              ?LOG_LV(?LV_STATUS,"End =~p~n",[End]),
              MatchesString=string:substr(WhiteListString,Start,End),
%%              ?LOG_LV(?LV_STATUS,"Match String=~p~n",[MatchesString]),
              DeviceLists=string:tokens(MatchesString,","),
%%              ?LOG_LV(?LV_STATUS,"Device List String=~p~n",[DeviceLists]),
              List=intstr_list_to_list(DeviceLists),
%%              ?LOG_LV(?LV_STATUS,"Device List=~p~n",[List]),
              case List of
                error -> all;
                [] -> all;
                L -> L
              end
          end;
        _Else -> all
      end;
    true -> WhiteListString
  end.

get_white_list([])-> all;
get_white_list([H|T]) ->
%%  ?LOG_LV(?LV_STATUS,"get_white_list~p~n",[H]),
  if
    H==41 ->
%%      ?LOG_LV(?LV_STATUS,"Is number~n"),
      all;
    is_map(H) ->
      PK_Exist=maps:is_key(<<"PK">>,H),
%%      ?LOG_LV(?LV_STATUS,"Is Map~n"),
      if
        PK_Exist ->
          PK = maps:get(<<"PK">>,H),
%%          ?LOG_LV(?LV_STATUS,"PK=~p~n",[PK]),
          PK_Perm41=(PK==41),
          if
            PK_Perm41 ->
%%              ?LOG_LV(?LV_STATUS,"Is perm 41~n"),
              ArgumentExist=maps:is_key(<<"Arguments">>,H),
              if
                ArgumentExist->
                  Arguments= maps:get(<<"Arguments">>,H),
%%                  ?LOG_LV(?LV_STATUS,"Arguments~p~n",[Arguments]),
                  process_white_list(bin_to_list(Arguments));
                true ->
%%                  ?LOG_LV(?LV_STATUS,"No Arguments~n"),
                  all
              end;
            true -> get_white_list(T)
          end;
        true-> get_white_list(T)
      end;
    true -> get_white_list(T)
  end.

get_timestamp()->
  {Mega, Secs, _} = erlang:timestamp(),
  Timestamp = Mega*1000000 + Secs,
  Timestamp.

get_PK_Account(IdentityJson) ->
  AccountChildExist = maps:is_key(<<"PK_AccountChild">>,IdentityJson),
  PK_Account=maps:get(<<"PK_Account">>,IdentityJson),
  if
    AccountChildExist ->
      case maps:get(<<"PK_AccountChild">>,IdentityJson) of
        0 ->
          PK_Account;
        PK_AccountChild ->
          PK_AccountChild
      end;
    true ->
      PK_Account
  end.

get_PK_Device(IdentityJson) ->
  PK_DeviceExist = maps:is_key(<<"PK_Device">>,IdentityJson),
  if
    PK_DeviceExist ->
      PK_Device = maps:get(<<"PK_Device">>,IdentityJson),
      PK_Device;
    true ->
      0
  end.

isDeviceToken(PK_Device) ->
  case PK_Device of
    0 ->
      false;
    _PK_Device ->
      true
  end.

get_token_type(IdentityJson) when ?EMPTY(IdentityJson) ->
  throw(identity_undefined);
get_token_type(IdentityJson) ->
  Valid=maps:is_key(<<"PK_Account">>,IdentityJson) and maps:is_key(<<"Expires">>,IdentityJson),
  if
    Valid ->
      ExpireTime = maps:get(<<"Expires">>,IdentityJson),
      Now=get_timestamp(),
      ?LOG_LV(?LV_STATUS,"Expiration: ~p, now: ~p~n",[ExpireTime,Now]),
      Expired = ExpireTime<Now,
      PK_Device = get_PK_Device(IdentityJson),
      DeviceExist = isDeviceToken(PK_Device),
      UserExist =maps:is_key(<<"PK_User">>,IdentityJson) and
        maps:is_key(<<"PK_Server_Auth">>,IdentityJson) and
        maps:is_key(<<"Seq">>,IdentityJson) and
        maps:is_key(<<"Generated">>,IdentityJson) and
        maps:is_key(<<"Username">>,IdentityJson),

      if
        Expired->
          ?LOG_LV(?LV_WARNING,"Token expired ~p seconds ago~n",[ExpireTime-Now]),
          expired;
        DeviceExist ->
          ?LOG_LV_0(?LV_DEBUG,"It's a device token~n"),
          PK_Account=maps:get(<<"PK_Account">>,IdentityJson),
          {device,PK_Account,PK_Device};
        UserExist ->
          ?LOG_LV_0(?LV_DEBUG,"It's a user token~n"),
          PK_User=maps:get(<<"PK_User">>,IdentityJson),
          PK_Server_Auth=maps:get(<<"PK_Server_Auth">>,IdentityJson),
          Seq=maps:get(<<"Seq">>,IdentityJson),
          Generated=maps:get(<<"Generated">>,IdentityJson),
          Client_Id=to_string(PK_User) ++
          "_" ++ to_string(PK_Server_Auth) ++
          "_" ++ to_string(Seq) ++
          "_" ++ to_string(Generated),
%%          ?LOG_LV(?LV_STATUS,"ClientId ~p~n",[Client_Id]),
          PK_Account=get_PK_Account(IdentityJson),
          Username = binary_to_list(maps:get(<<"Username">>,IdentityJson)),
          PermissionsExist=maps:is_key(<<"PermissionsEnabled">>,IdentityJson),
          if
            PermissionsExist ->
              Permissions = maps:get(<<"PermissionsEnabled">>,IdentityJson),
%%              ?LOG_LV(?LV_STATUS,"Permissions exist: ~p~n",[Permissions]),
              WhiteList=get_white_list(Permissions),
              ?LOG_LV(?LV_STATUS,"WhiteList: ~p~n",[WhiteList]),
              {user, PK_Account,Client_Id,Username,WhiteList};
            true->
              {user, PK_Account,Client_Id,Username,all}
          end;
        true-> throw(invalid_token)
      end;
    true-> throw(invalid_token)
  end.

clean_device_client_id(ClientID)->
  Parts=string:tokens(ClientID,"_"),
  Length= length(Parts),
  if
    Length>=1->
      lists:nth(1,Parts);
    true ->
      ClientID
  end.


do_auth(PublicKey,ClientId, Username,Password)->
  case maps:is_key(<<"Identity">>,Password) and maps:is_key(<<"IdentitySignature">>,Password) of
    true ->
      Identity=maps:get(<<"Identity">>,Password),
      IdentitySignature=maps:get(<<"IdentitySignature">>,Password),
      SignatureVerified = (PublicKey == no_verify) orelse (verify_signature(Identity,IdentitySignature,PublicKey)),
      if
        SignatureVerified ->
          IdentityDecoded = decode_base64(Identity),
          IdentityJson = get_json(IdentityDecoded),
          case get_token_type(IdentityJson) of
            {user,PK_Account,TokenClientId,TokenUsername,WhiteList} ->
              Authorized = (Username == TokenUsername) and (TokenClientId==ClientId),
              ?LOG_LV(?LV_WARNING,"Required Username: ~p  Username: ~p~n",[TokenUsername, Username]),
              ?LOG_LV(?LV_WARNING,"Required ClientId: ~p  ClientId: ~p~n",[TokenClientId,ClientId]),
              if
                Authorized ->
                  register_user(PK_Account,ClientId,WhiteList),
                  update_clients(PK_Account),
                  ?LOG_LV(?LV_STATUS,"Allowed user ~p~n-----------------------~n",[ClientId]),
                  ok;
                true->
                  {error,not_authorized}
              end;
            {device,PK_Account,PK_Device} ->
              PK_DeviceStr=to_string(PK_Device),
              CleanedClientId= clean_device_client_id(ClientId),
              Authorized = (Username == PK_DeviceStr) and (PK_DeviceStr==CleanedClientId),
              ?LOG_LV(?LV_DEBUG,"Required Username: ~p  Username: ~p~n",[PK_DeviceStr, Username]),
              ?LOG_LV(?LV_DEBUG,"Required ClientId: ~p  ClientId: ~p~n",[PK_DeviceStr,CleanedClientId]),
              if
                Authorized ->
                  register_device(PK_Account,PK_Device,ClientId),
                  update_clients(PK_Account),
                  ?LOG_LV(?LV_STATUS,"Allowed device ~p~n-----------------------~n",[PK_Device]),
                  ok;
                true->
                  {error,not_authorized}
              end;
            expired ->
              ?LOG_LV_0(?LV_WARNING,"Token expired~n"),
              {error,expired_token};
            _Else ->
              ?LOG_LV(?LV_ERROR,"Unrecognized TokenType ~p~n",[_Else]),
              {error,unrecongized_token}
          end;
        true ->
          ?LOG_LV_0(?LV_ERROR,"Signature Failed ~n"),
          {error,signature_failed}
      end;
    false ->
      ?LOG_LV_0(?LV_ERROR,"Token unrecognized ~n"),
      {error,token_unrecognized}
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
%%  ?LOG_LV(?LV_STATUS,"ClientID: ~p~nUsername: ~p~nPassword: ~p~n",[ClientId,UserName,Password]),
  try
    JsonToken = get_json(Password),
    if
      is_map(JsonToken) -> do_auth(PublicKey,ClientId,UserName,JsonToken);
      true->{error,invalid_token}
    end
  catch
    throw:Error ->
      ?LOG_LV(?LV_STATUS,"Throw ~p~n",[Error]),
      {error,Error}
  end.


register_device(PK_Account,PK_Device,ClientId) ->
  ?LOG_LV(?LV_STATUS,"Device ~p inserted~n",[PK_Device]),
  ets:insert(?DEVICES_DATABASE,{PK_Account,PK_Device,ClientId}),
  ets:insert(?CLIENTS_DATABASE,{ClientId,device,{PK_Account,PK_Device}}).


register_user(PK_Account,ClientId,WhiteList) ->
  ?LOG_LV(?LV_STATUS,"User ~p inserted~n",[ClientId]),
  ets:insert(?USERS_DATABASE,{PK_Account,ClientId,WhiteList}),
  ets:insert(?CLIENTS_DATABASE,{ClientId,user,{PK_Account,ClientId}}).

ets_lookup(Table,Key) ->
  TableNotExist=(ets:info(Table)==undefined),
  if
    TableNotExist -> [];
    true->
      ets:lookup(Table,Key)
  end.

update_clients(PK_Account) ->
  ?LOG_LV(?LV_STATUS,"Updating clients on Account ~p~n",[PK_Account]),
  Devices = ets_lookup(?DEVICES_DATABASE,PK_Account),
  ?LOG_LV(?LV_STATUS,"Devices: ~p~n",[Devices]),
  Users = ets_lookup(?USERS_DATABASE,PK_Account),
  ?LOG_LV(?LV_STATUS,"Users: ~p~n",[Users]),
  update_users_topics(Users,Devices),
  update_device_topics(Devices,Users),
  ?LOG_LV(?LV_STATUS,"Done Updating clients on Account ~p~n",[PK_Account]).

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
  {_,PK_Device,_}=H,
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
  ?LOG_LV(?LV_DEBUG,"~p Ending with topics: ~p~n",[ClientId,NewTopics]),
  NewTopics.



get_device_topics(PK_Device,UsersList)->
  get_device_topics(PK_Device,UsersList,{[],[]}).

get_device_topics(PK_Device,[H|T],Topics)->
  {_,ClientId,WhiteList}=H,
  Update = (WhiteList == all) orelse (list_contains(PK_Device,WhiteList)),
  if
    Update ->
      NewPubTopics = [
          to_string(PK_Device)++"/"++ClientId++"/ud"],
      NewSubTopics = [
          to_string(PK_Device)++"/"++ClientId++"/alive"],
%%      ?LOG_LV(?LV_STATUS,"get_device_topics: Topics: ~p~n",[Topics]),
      NewTopics=insert_topics(NewSubTopics,NewPubTopics,Topics),
      get_device_topics(PK_Device,T,NewTopics);
    true ->
      get_device_topics(PK_Device,T,Topics)
  end;
get_device_topics(PK_Device,[],Topics)->
  Pub=[to_string(PK_Device)++"/connected",
      to_string(PK_Device)++"/source",
      to_string(PK_Device)++"/+/out"],
  Sub=["+/connected",
      to_string(PK_Device)++"/source",
      to_string(PK_Device)++"/+/in"],
  NewTopics= insert_topics(Sub,Pub,Topics),
  ?LOG_LV(?LV_DEBUG,"~p Ending with topics: ~p~n",[PK_Device,NewTopics]),
  NewTopics.



update_users_topics([H|L],DeviceList)->
  {_,ClientId,WhiteList}=H,
  NewTopics=get_user_topics(ClientId,DeviceList,WhiteList),
%%  create_table(topics,set),
  ets:insert(?TOPICS_DATABASE,{ClientId,NewTopics}),
  ?LOG_LV(?LV_DEBUG,"Topics for user ~p are: ~p~n",[ClientId,NewTopics]),
  update_users_topics(L,DeviceList);
update_users_topics([],_)-> none.

update_device_topics([H|L],UserList)->
  {_,PK_Device,ClientId}=H,
  NewTopics=get_device_topics(PK_Device,UserList),
%%  create_table(topics,set),
  ets:insert(?TOPICS_DATABASE,{ClientId,NewTopics}),
  ?LOG_LV(?LV_DEBUG,"Topics for device ~p are: ~p~n",[PK_Device,NewTopics]),
  update_device_topics(L,UserList);
update_device_topics([],_)-> none.

create_table(Name,Type) ->
  TableNotExist = (ets:info(Name)==undefined),
  if
    TableNotExist ->
      ets:new(Name,[Type,named_table,public]);
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
  TableNotExist = (ets:info(?CLIENTS_DATABASE)==undefined),
  if
    TableNotExist->
      ok;
    true->
      Info= ets_lookup(?CLIENTS_DATABASE,Client),
      InfoLen=length(Info),
      if
        InfoLen==1 ->
          [Element]=Info,
          {_,Type,Data}=Element,
          ets:match_delete(?CLIENTS_DATABASE,Element),
          delete_topic(Client),
          case Type of
            user ->
              {PK_Account,ClientId}=Data,
              delete_user(PK_Account,ClientId),
              ?LOG_LV(?LV_STATUS,"Deleting user: ~p~n",[ClientId]),
              update_clients(PK_Account);
            device->
              {PK_Account,PK_Device}=Data,
              delete_device(PK_Account,PK_Device),
              ?LOG_LV(?LV_STATUS,"Deleting device: ~p~n",[PK_Device]),
              update_clients(PK_Account)
          end;
        true->
          ?LOG_LV(?LV_ERROR,"Client: ~p does not exist~n",[Client]),
          ok
      end
  end.


delete_topic(Client)->
  TableNotExist = (ets:info(?TOPICS_DATABASE)==undefined),
  if
    TableNotExist -> ok;
    true -> ets:match_delete(?TOPICS_DATABASE,{Client,'_'})
  end.

delete_user(PK_Account,ClientId)->
  TableNotExist = (ets:info(?USERS_DATABASE)==undefined),
  if
    TableNotExist -> ok;
    true -> ets:match_delete(?USERS_DATABASE,{PK_Account,ClientId,'_'})
  end.

delete_device(PK_Account,PK_Device)->
  TableNotExist = (ets:info(?DEVICES_DATABASE)==undefined),
  if
    TableNotExist -> ok;
    true -> ets:match_delete(?DEVICES_DATABASE,{PK_Account,PK_Device})
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
topic_match_splited(_H1,[H2]) when H2=="#"->true;
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
  Topics=ets_lookup(?TOPICS_DATABASE,ClientId),

  if
    length(Topics)==1 ->
      [{_ClientId,{Sub,Pub}}]=Topics,
      case PubSub of
        publish->
          Match = topic_match(Topic,Pub),
          if
            Match -> true;
            true ->
              ?LOG_LV(?LV_WARNING,"ACL Denied ClientId: ~p, trying to publish to topic: ~p but is allowed only to: ~p~n",[ClientId,Topic,Pub]),
              false
          end;
        subscribe->
          Match=topic_match(Topic,Sub),
          if
            Match -> true;
            true ->
              ?LOG_LV(?LV_WARNING,"ACL Denied ClientId: ~p, trying to subscribe to topic: ~p but is allowed only to: ~p~n",[ClientId,Topic,Sub]),
              false
          end;
          _Else ->
          ?LOG_LV(?LV_ERROR,"ACL Unrecongnized event ~p~n",[_Else]),
          false
      end;
    true->
      false
  end.

create_tables()->
  create_table(?DEVICES_DATABASE,bag),
  create_table(?USERS_DATABASE,bag),
  create_table(?CLIENTS_DATABASE,set),
  create_table(?TOPICS_DATABASE,set).

delete_tables()->
  delete_table(?DEVICES_DATABASE),
  delete_table(?USERS_DATABASE),
  delete_table(?CLIENTS_DATABASE),
  delete_table(?TOPICS_DATABASE).


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
  KeysSet = sets:from_list(keys(?USERS_DATABASE)++keys(?DEVICES_DATABASE)),
  update_all_clients(KeysSet).
update_all_clients([H|T])->
  update_clients(H),
  update_all_clients(T);
update_all_clients([])->
  ok.

