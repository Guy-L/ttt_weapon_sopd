$modelname "Weapons/v_sopd.mdl"

$bodygroup "studio"
{
	studio "v_sopd_reference.smd"
}

$surfaceprop "default"

$contents "solid"

$illumposition 11.423 26.487 1.395

$cdmaterials "models\Weapons\V_hand\"
$cdmaterials "models/ttt/sopd/"
$attachment "0" "ValveBiped.Tip" 0 0 0 rotate 0 0 0

$cbox 0 0 0 0 0 0

$bbox 7.979 -32.627 -40.226 45.347 39.988 30.096

$hboxset "default"
$hbox 0 "ValveBiped.Bip01_Spine4" 0 0 -1.938 2.033 1.001 0
$hbox 0 "ValveBiped.Bip01_R_UpperArm" 0 -2.168 -2.128 11.693 2.722 2.705
$hbox 0 "ValveBiped.Bip01_R_Forearm" -1.958 -3.135 -2.804 11.482 2.55 3.047
$hbox 0 "ValveBiped.Bip01_R_Hand" 0 -3.141 -50.110001 5.531 0.938 7.2
$hbox 0 "ValveBiped.HandControlRotR" 0 -1.935 -15.15 11.123 0 0

$definebone "ValveBiped.Bip01" "" 0.485443 -29.181845 35.963909 0 0 89.999982 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_Spine" "ValveBiped.Bip01" 0.000007 4.987328 -4.445776 4.944225 89.999982 89.999982 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_Spine1" "ValveBiped.Bip01_Spine" 5.991016 -0.000011 0 0 -1.675443 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_Spine2" "ValveBiped.Bip01_Spine1" 5.245903 -0.000011 0 0 5.74883 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_Spine4" "ValveBiped.Bip01_Spine2" 13.332779 0.000004 0 0 11.120882 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Clavicle" "ValveBiped.Bip01_Spine4" 3.031586 1.492069 -2.888829 73.71203 168.618779 -95.596557 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_UpperArm" "ValveBiped.Bip01_R_Clavicle" 8.987497 -0.000015 0.000004 78.95364 -88.12584 91.732596 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Forearm" "ValveBiped.Bip01_R_UpperArm" 17.432716 -0.000015 -0.000005 0 -18.575692 -0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Hand" "ValveBiped.Bip01_R_Forearm" 17.11837 -0.000004 -0.000001 0.513542 -3.125944 -105.465142 0 0 0 0 0 0
$definebone "ValveBiped.HandControlRotR" "" 0.485451 13.601772 -21.536434 5.625013 -5.625013 -15.749977 0 0 0 0 0 0
$definebone "ValveBiped.Tip" "ValveBiped.HandControlRotR" 16.583706 -2.885614 -22.58773 -0.537148 -92.19487 -39.209626 0 0 0 0 0 0

$bonemerge "ValveBiped.Bip01"
$bonemerge "ValveBiped.Bip01_Spine"
$bonemerge "ValveBiped.Bip01_Spine1"
$bonemerge "ValveBiped.Bip01_Spine2"
$bonemerge "ValveBiped.Bip01_Spine4"
$bonemerge "ValveBiped.Bip01_R_Clavicle"
$bonemerge "ValveBiped.Bip01_R_UpperArm"
$bonemerge "ValveBiped.Bip01_R_Forearm"
$bonemerge "ValveBiped.Bip01_R_Hand"
$bonemerge "ValveBiped.HandControlRotR"


$sequence "idle01" {
	"v_sopd_anims\idle01.smd"
	activity "ACT_VM_IDLE" 1
	fadein 0.2
	fadeout 0.2
	fps 30
	loop
}

$sequence "draw" {
	"v_sopd_anims\draw.smd"
	activity "ACT_VM_DRAW" 1
	fadein 0.2
	fadeout 0.2
	fps 30
}

$sequence "misscenter1" {
	"v_sopd_anims\misscenter1.smd"
	activity "ACT_VM_MISSCENTER" 1
	fadein 0.2
	fadeout 0.2
	fps 30
}

$sequence "misscenter2" {
	"v_sopd_anims\misscenter2.smd"
	activity "ACT_VM_MISSCENTER" 1
	fadein 0.2
	fadeout 0.2
	fps 30
}

$sequence "hitcenter1" {
	"v_sopd_anims\hitcenter1.smd"
	activity "ACT_VM_HITCENTER" 1
	fadein 0.2
	fadeout 0.2
	fps 30
}

$sequence "hitcenter2" {
	"v_sopd_anims\hitcenter2.smd"
	activity "ACT_VM_HITCENTER" 1
	fadein 0.2
	fadeout 0.2
	fps 30
}

$sequence "hitcenter3" {
	"v_sopd_anims\hitcenter3.smd"
	activity "ACT_VM_HITCENTER" 1
	fadein 0.2
	fadeout 0.2
	fps 30
}

$sequence "hitkill1" {
	"v_sopd_anims\hitkill1.smd"
	activity "ACT_VM_HITKILL" 1
	fadein 0.2
	fadeout 0.2
	fps 30
}

$sequence "holster" {
	"v_sopd_anims\holster.smd"
	activity "ACT_VM_HOLSTER" 1
	fadein 0.2
	fadeout 0.2
	fps 30
}
