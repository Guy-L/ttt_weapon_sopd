// Created by Crowbar 0.74

$modelname "weapons/w_sopd.mdl"

$bodygroup "studio"
{
	studio "w_sopd_reference.smd"
}

$surfaceprop "crowbar"

$contents "solid"

$illumposition 1.857 10.65 0.762

$cdmaterials "models/ttt/sopd/"

$cbox 0 0 0 0 0 0

$bbox -34.613 -4.684 -4.153 16.011 6.644 5.777

$definebone "ValveBiped.Bip01_R_Hand" "" -0.631371 -6.659214 -3.65312 -74.60186 -163.122348 -102.294862 0 0 0 0 0 0


$sequence "idle" {
	"w_sopd_anims\sopd_idle.smd"
	activity "ACT_VM_IDLE" 1
	fadein 0.2
	fadeout 0.2
	fps 30
	loop
}

$sequence "attack1" {
	"w_sopd_anims\sopd_attack1.smd"
	fadein 0.2
	fadeout 0.2
	fps 30
}

$collisionmodel "w_sopd_physics.smd"
{
	$mass 4
	$inertia 3
	$damping 1.5
	$rotdamping 1
	$rootbone "ValveBiped.Bip01_R_Hand"
}
