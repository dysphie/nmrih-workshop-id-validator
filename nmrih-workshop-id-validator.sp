#include <system2>

#pragma newdecls required
#pragma semicolon 1

#define URL "http://api.steampowered.com/ISteamRemoteStorage/ValidateWorkshopFile/v1/"

ConVar cvWorkshopMapID;
bool validatedMapId;

public Plugin myinfo = 
{
	name        = "[NMRiH] Workshop ID Validator",
	author      = "Dysphie",
	description = "Validates Workshop download IDs before replicating them to clients",
	version     = "0.1.0",
	url         = ""
};

public void OnPluginStart()
{
	cvWorkshopMapID = FindConVar("sv_workshop_map_id");
	cvWorkshopMapID.Flags &= ~FCVAR_REPLICATED;
	cvWorkshopMapID.AddChangeHook(OnWorkshopMapIdChanged);
}

public void OnClientConnected(int client)
{
	if (!validatedMapId)
		return;

	cvWorkshopMapID.Flags |= FCVAR_REPLICATED;

	char value[30];
	cvWorkshopMapID.GetString(value, sizeof(value));

	cvWorkshopMapID.ReplicateToClient(client, value);
	cvWorkshopMapID.Flags &= ~FCVAR_REPLICATED;
}

public void OnWorkshopMapIdChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(newValue, "-1"))
	{
		validatedMapId = false;
		ValidateWorkshopFile(newValue);
	}
}

void ValidateWorkshopFile(const char[] fileID)
{
	System2HTTPRequest request = new System2HTTPRequest(OnPublishedFileDetails, URL);
	request.SetData("itemcount=1&publishedfileids[0]=%s&format=vdf", fileID);
	request.Any = StringToInt(fileID);
	request.Timeout = 5;
	request.POST();
}

public void OnPublishedFileDetails(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) 
{
	bool goodResponse;

	if (success && response.StatusCode == 200) 
	{
		int contentSize = response.ContentLength + 1;
		char[] content = new char[contentSize];
		response.GetContent(content, contentSize);

		KeyValues kv = new KeyValues("response");
		goodResponse = kv.ImportFromString(content) && kv.JumpToKey("publishedfiledetails") && 
					kv.GotoFirstSubKey() && kv.GetNum("result") == 1;
		delete kv;
	}

	// Ensure convar value didn't change while we validated this one
	if (goodResponse && cvWorkshopMapID.IntValue == request.Any)
		validatedMapId = true;
}
