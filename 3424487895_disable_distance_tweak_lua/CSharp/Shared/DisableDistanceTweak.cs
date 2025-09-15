using System;
using Barotrauma;
using HarmonyLib;

using Barotrauma.Abilities;
using Barotrauma.Extensions;
using Barotrauma.IO;
using Barotrauma.Items.Components;
using Barotrauma.Networking;
using FarseerPhysics;
using FarseerPhysics.Dynamics;
using Microsoft.Xna.Framework;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Diagnostics;
using System.Linq;
using System.Xml.Linq;
using System.Text;
using Voronoi2;
using Barotrauma.Items.Components;
using FarseerPhysics;
using System.Reflection;

namespace DisableDistanceTweak {
	class DisableDistanceTweak : IAssemblyPlugin {
		
		public Harmony harmony;
		
		public void Initialize()
		{
			harmony = new Harmony("DisableDistanceTweak.mod");
			
			harmony.Patch(
				original: typeof(Character).GetMethod("UpdateAll"),
				prefix: new HarmonyMethod(typeof(Plugin).GetMethod("Character_UpdateAll_Replace"))
			);
			
			harmony.Patch(
				original: typeof(Submarine).GetMethod("Update"),
				prefix: new HarmonyMethod(typeof(Plugin).GetMethod("Submarine_Update_Replace"))
			);
			
			/*
			harmony.Patch(
				original: typeof(MapEntity).GetMethod("UpdateAll"),
				prefix: new HarmonyMethod(typeof(Plugin).GetMethod("MapEntity_UpdateAll_Replace"))
			);
			*/
		}
		
		public void OnLoadCompleted() { }
		public void PreInitPatching() { }
		
		public void Dispose()
		{
			harmony.UnpatchSelf();
			harmony = null;
		}
		
		public class Plugin
		{
			public static bool IsCloseDistanceSqrtToMainSubOrClosestAlivePlayer(Vector2 objWorldPos, float CloseDistance)
			{
				float distSqrt = (float)Math.Sqrt(Vector2.DistanceSquared(Submarine.MainSub.WorldPosition, objWorldPos));
				if (distSqrt < CloseDistance) { return true; }
				foreach (Character c in Character.CharacterList)
				{
					if (c.IsDead || !c.IsRemotePlayer || c.Submarine == Submarine.MainSub) { continue; }
					distSqrt = Math.Min(distSqrt, (float)Math.Sqrt(Vector2.DistanceSquared((c.ViewTarget == null) ? c.WorldPosition : c.ViewTarget.WorldPosition, objWorldPos)));
					if (distSqrt < CloseDistance) { return true; }
				}				
				return false;
			}
			
			/*
			public static float GetDistanceSqrtToClosestAlivePlayerOrMainSub(Vector2 objWorldPos)
			{
				float distSqrt = (float)Math.Sqrt(Vector2.DistanceSquared(Submarine.MainSub.WorldPosition, objWorldPos));
				foreach (Character c in Character.CharacterList)
				{
					if (c.IsDead || !c.IsRemotePlayer) { continue; }
					distSqrt = Math.Min(distSqrt, (float)Math.Sqrt(Vector2.DistanceSquared((c.ViewTarget == null) ? c.WorldPosition : c.ViewTarget.WorldPosition, objWorldPos)));
				}				
				return distSqrt;
			}
			*/
			
			public static bool Character_UpdateAll_Replace(float deltaTime, Camera cam)
			{				
				foreach (Character c in Character.CharacterList)
				{
					if (c == null || (c is not AICharacter && !c.IsRemotePlayer)) { continue; }
					
					if (c.IsPlayer || (c.IsBot && c.IsOnPlayerTeam))
					{
						c.Enabled = true;
						continue;
					}
					
					//disable AI characters that are far away from the sub, all clients and the host's character and not controlled by anyone
					if (!IsCloseDistanceSqrtToMainSubOrClosestAlivePlayer(c.WorldPosition, c.Params.DisableDistance))
					{
						//LuaCsLogger.LogMessage(distSqrt.ToString(), Color.Yellow,  Color.Yellow);
						c.Enabled = false;
						
						if (c.IsDead && c.AIController is EnemyAIController && (c.Inventory == null || c.Inventory.IsEmpty()))
						{
							Entity.Spawner?.AddEntityToRemoveQueue(c);
						}
					}
					else
					{
						c.Enabled = true;
					}
				}

				Character.characterUpdateTick++;

				if (Character.characterUpdateTick % Character.CharacterUpdateInterval == 0)
				{
					for (int i = 0; i < Character.CharacterList.Count; i++)
					{
						var character = Character.CharacterList[i];
						if (character == null || character.Removed) { continue; }
						
						if (GameMain.LuaCs.Game.UpdatePriorityCharacters.Contains(character)) continue;
						
						character.Update(deltaTime * Character.CharacterUpdateInterval, cam);
					}
				}

				foreach (Character character in GameMain.LuaCs.Game.UpdatePriorityCharacters)
				{
					if (character == null || character.Removed) { continue; }

					character.Update(deltaTime, cam);
				}
				
				return false;
			}
			
			public const float DisableDistanceSub = 8500.0f;
			public const float DisableDistanceEnemySub = 12500.0f;
			
			public static bool Submarine_Update_Replace(float deltaTime, Submarine __instance)
			{
				bool NeedUpdateSub = false;
				
				// Always update main sub
				if (__instance == Submarine.MainSub)
				{
					//DebugConsole.NewMessage("MainSub", new Color(0, 0, 255));
					//DebugConsole.NewMessage(__instance.ToString(), new Color(0, 0, 255));
					NeedUpdateSub = true;
				}
				else
				{
					// Always update sub with players inside
					foreach (Character c in Character.CharacterList)
					{
						if (c.IsPlayer || (c.IsBot && c.IsOnPlayerTeam))
						{
							if (c.Submarine == __instance)
							{
								//DebugConsole.NewMessage("PlayerSub", new Color(0, 255, 0));
								//DebugConsole.NewMessage(__instance.ToString(), new Color(0, 255, 0));
								NeedUpdateSub = true;
								break;
							}
						}
					}
					
					// Update by distance
					if (!NeedUpdateSub)
					{
						if (IsCloseDistanceSqrtToMainSubOrClosestAlivePlayer(__instance.WorldPosition, (__instance.Info.Type == SubmarineType.EnemySubmarine) ? DisableDistanceEnemySub : DisableDistanceSub))
						{
							//DebugConsole.NewMessage("CloseDistanceSub", new Color(255, 255, 0));
							//DebugConsole.NewMessage(GetDistanceSqrToClosestAlivePlayer(__instance.WorldPosition).ToString(), new Color(255, 255, 0));
							//DebugConsole.NewMessage(__instance.ToString(), new Color(255, 255, 0));
							NeedUpdateSub = true;
						}
					}
				}
				
				if (NeedUpdateSub)
				{
					__instance.RefreshConnectedSubs();

					if (__instance.Info.IsWreck)
					{
						__instance.WreckAI?.Update(deltaTime);
					}
					__instance.TurretAI?.Update(deltaTime);

					if (__instance.subBody?.Body == null) { return false; }

					if (Level.Loaded != null &&
						__instance.WorldPosition.Y < Level.MaxEntityDepth &&
						__instance.subBody.Body.Enabled &&
						!__instance.IsRespawnShuttle)
					{
						__instance.subBody.Body.ResetDynamics();
						__instance.subBody.Body.Enabled = false;

						foreach (Character c in Character.CharacterList)
						{
							if (c.Submarine == __instance)
							{
								c.Kill(CauseOfDeathType.Pressure, null);
								c.Enabled = false;
							}
						}

						return false;
					}


					__instance.subBody.Body.LinearVelocity = new Vector2(
						Submarine.LockX ? 0.0f : __instance.subBody.Body.LinearVelocity.X,
						Submarine.LockY ? 0.0f : __instance.subBody.Body.LinearVelocity.Y);

					__instance.subBody.Update(deltaTime);

					for (int i = 0; i < 2; i++)
					{
						if (Submarine.MainSubs[i] == null) { continue; }
						if (__instance != Submarine.MainSubs[i] && Submarine.MainSubs[i].DockedTo.Contains(__instance)) { return false; }
					}

					//send updates more frequently if moving fast
					__instance.networkUpdateTimer -= MathHelper.Clamp(__instance.Velocity.Length() * 10.0f, 0.1f, 5.0f) * deltaTime;

					if (__instance.networkUpdateTimer < 0.0f)
					{
						__instance.networkUpdateTimer = 1.0f;
					}
					//return false;
				}
				//DebugConsole.NewMessage("NotUpdatedSub", new Color(255, 0, 0));
				//DebugConsole.NewMessage(GetDistanceSqrtToClosestAlivePlayerOrMainSub(__instance.WorldPosition).ToString(), new Color(255, 0, 0));
				//DebugConsole.NewMessage(__instance.ToString(), new Color(255, 0, 0));
				return false;
			}
			
			/*
			public static bool MapEntity_UpdateAll_Replace(float deltaTime, Camera cam)
			{				
				MapEntity.mapEntityUpdateTick++;
				
				if (MapEntity.mapEntityUpdateTick % MapEntity.MapEntityUpdateInterval == 0)
				{	
					foreach (Hull hull in Hull.HullList)
					{
						hull.Update(deltaTime * MapEntity.MapEntityUpdateInterval, cam);
					}
	
					foreach (Structure structure in Structure.WallList)
					{
						structure.Update(deltaTime * MapEntity.MapEntityUpdateInterval, cam);
					}
				}
	
				//update gaps in random order, because otherwise in rooms with multiple gaps
				//the water/air will always tend to flow through the first gap in the list,
				//which may lead to weird behavior like water draining down only through
				//one gap in a room even if there are several
				foreach (Gap gap in Gap.GapList.OrderBy(g => Rand.Int(int.MaxValue)))
				{
					gap.Update(deltaTime, cam);
				}
	
				if (MapEntity.mapEntityUpdateTick % MapEntity.PoweredUpdateInterval == 0)
				{
					Powered.UpdatePower(deltaTime * MapEntity.PoweredUpdateInterval);
				}
	
				Item.UpdatePendingConditionUpdates(deltaTime);
				if (MapEntity.mapEntityUpdateTick % MapEntity.MapEntityUpdateInterval == 0)
				{
					Item lastUpdatedItem = null;
	
					try
					{
						foreach (Item item in Item.ItemList)
						{
							if (GameMain.LuaCs.Game.UpdatePriorityItems.Contains(item)) { continue; }
							if (item.WorldPosition != null && GetDistanceSqrtToClosestAlivePlayerOrMainSub(item.WorldPosition) > 12500.0f) { continue; }
							lastUpdatedItem = item;
							item.Update(deltaTime * MapEntity.MapEntityUpdateInterval, cam);
						}
					}
					catch (InvalidOperationException e)
					{
						GameAnalyticsManager.AddErrorEventOnce(
							"MapEntity.UpdateAll:ItemUpdateInvalidOperation", 
							GameAnalyticsManager.ErrorSeverity.Critical, 
							$"Error while updating item {lastUpdatedItem?.Name ?? "null"}: {e.Message}");
						throw new InvalidOperationException($"Error while updating item {lastUpdatedItem?.Name ?? "null"}", innerException: e);
					}
				}
	
				foreach (var item in GameMain.LuaCs.Game.UpdatePriorityItems)
				{
					if (item.Removed) continue;
					if (item.WorldPosition != null && GetDistanceSqrtToClosestAlivePlayerOrMainSub(item.WorldPosition) > 12500.0f) { continue; }
					item.Update(deltaTime, cam);
				}
	
				if (MapEntity.mapEntityUpdateTick % MapEntity.MapEntityUpdateInterval == 0)
				{
					//MapEntity.UpdateAllProjSpecific(deltaTime * MapEntityUpdateInterval);
	
					MapEntity.Spawner?.Update();
				}
				
				return false;
			}
			*/
		}
	}
}