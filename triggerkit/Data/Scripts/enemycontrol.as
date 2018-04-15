#include "aschar.as"
#include "situationawareness.as"

// Moved out of enemycontrol_vanilla
Situation situation;
int got_hit_by_leg_cannon_count = 0;

void GetPath(vec3 target_pos) {
    def::path = GetPath(this_mo.position,
                   target_pos,
                   def::inclusive_flags,
                   def::exclusive_flags);
    def::current_path_point = 0;
}
// End moved out of enemycontrol_vanilla

namespace def {
    #include "enemycontroldebug.as"
    #include "enemycontrol_vanilla.as"
}

bool triggerkit_has_control = true;
bool triggerkit_jump = false;

int IsUnaware() {
    if (triggerkit_has_control) {
        return 0;
    }

    return def::IsUnaware();
}

void AIMovementObjectDeleted(int id) {
    def::AIMovementObjectDeleted(id);
}

string GetIdleOverride(){
    if (triggerkit_has_control) {
        return "";
    }
    
    return def::GetIdleOverride();
}

void DrawStealthDebug() {
    def::DrawStealthDebug();
}

bool DeflectWeapon() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::DeflectWeapon();
}

int IsAggro() {
    if (triggerkit_has_control) {
        return 0;
    }
    
    return def::IsAggro();
}

bool StuckToNavMesh() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::StuckToNavMesh();
}

void UpdateBrain(const Timestep &in ts){
    if (triggerkit_has_control) {
        return;
    }
    
    def::UpdateBrain(ts);
}

void AIEndAttack(){
    if (triggerkit_has_control) {
        return;
    }
    
    def::AIEndAttack();
}

vec3 GetTargetJumpVelocity() {
    if (triggerkit_has_control) {
        return vec3();
    }
    
    return def::GetTargetJumpVelocity();    
}

bool TargetedJump() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::TargetedJump();
}

bool IsAware(){
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::IsAware();
}

void ResetMind() {
    if (triggerkit_has_control) {
        return;
    }
    
    def::ResetMind();
}

int IsIdle() {
    if (triggerkit_has_control) {
        return 1;
    }
    
    return def::IsIdle();
}

void HandleAIEvent(AIEvent event){
    if (triggerkit_has_control) {
        if (event == _damaged) {
            triggerkit_has_control = false;
        }

        return;
    }
    
    def::HandleAIEvent(event);
}

void MindReceiveMessage(string msg){
    TokenIterator token_iter;
    token_iter.Init();
    if(!token_iter.FindNextToken(msg)){
        return;
    }
    string token = token_iter.GetToken(msg);

    if (token == "triggerkit_jump") {
        triggerkit_jump = true;
    } else {
        def::MindReceiveMessage(msg);
    }
}

bool WantsToCrouch() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToCrouch();
}

bool WantsToRoll() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToRoll();
}

bool WantsToJump() {
    if (triggerkit_has_control) {
        return false;
    }
    
    /*if (triggerkit_jump) {
        return true;
    }*/

    return def::WantsToJump();
}

bool WantsToAttack() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToAttack();
}

bool WantsToRollFromRagdoll(){
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToRollFromRagdoll();
}

void BrainSpeciesUpdate() {
    if (triggerkit_has_control) {
        return;
    }
    
    def::BrainSpeciesUpdate();
}

bool ActiveDodging(int attacker_id) {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::ActiveDodging(attacker_id);
}

bool ActiveBlocking() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::ActiveBlocking();
}

bool WantsToFlip() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToFlip();
}

bool WantsToGrabLedge() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToGrabLedge();
}

bool WantsToThrowEnemy() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToThrowEnemy();
}

void Startle() {
    def::Startle();
}

bool WantsToDragBody() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToDragBody();
}

bool WantsToPickUpItem() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToPickUpItem();
}

bool WantsToDropItem() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToDropItem();
}

bool WantsToThrowItem() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToThrowItem();
}

bool WantsToThroatCut() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToThroatCut();
}

bool WantsToSheatheItem() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToSheatheItem();
}

bool WantsToUnSheatheItem(int &out src) {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToUnSheatheItem(src);
}

bool WantsToStartActiveBlock(const Timestep &in ts){
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToStartActiveBlock(ts);
}

bool WantsToFeint(){
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToFeint();
}

bool WantsToCounterThrow(){
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToCounterThrow();
}

bool WantsToJumpOffWall() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToJumpOffWall();
}

bool WantsToFlipOffWall() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToFlipOffWall();
}

bool WantsToAccelerateJump() {
    if (triggerkit_has_control) {
        return false;
    }
    
    return def::WantsToAccelerateJump();
}

vec3 GetDodgeDirection() {
    return def::GetDodgeDirection();
}

bool WantsToDodge(const Timestep &in ts) {
    if (triggerkit_has_control) {
        return false;
    }

    return def::WantsToDodge(ts);
}

bool WantsToCancelAnimation() {
    if (triggerkit_has_control) {
        return false;
    }

    return def::WantsToCancelAnimation();
}

// Converts the keyboard controls into a target velocity that is used for movement calculations in aschar.as and aircontrol.as.
vec3 GetTargetVelocity() {
    return def::GetTargetVelocity();
}

// Called from aschar.as, bool front tells if the character is standing still. Only characters that are standing still may perform a front kick.
void ChooseAttack(bool front, string& out attack_str) {
    def::ChooseAttack(front, attack_str);
}

WalkDir WantsToWalkBackwards() {
    return def::WantsToWalkBackwards();
}

bool WantsReadyStance() {
    if (triggerkit_has_control) {
        return false;
    }

    return def::WantsReadyStance();
}

int CombatSong() {
    return def::CombatSong();
}

int IsAggressive() {
    return def::IsAggressive();
}

int GetLeftFootPlanted(){
    return def::GetLeftFootPlanted();
}

int GetRightFootPlanted(){
    return def::GetRightFootPlanted();
}
