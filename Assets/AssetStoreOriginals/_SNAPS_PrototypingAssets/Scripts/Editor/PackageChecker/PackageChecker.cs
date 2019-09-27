using System.IO;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEditor.PackageManager;
using UnityEditor.PackageManager.Requests;
using UnityEditor.Compilation;
using System;


namespace SNAP
{
    public class PackageChecker
    {

        private static ListRequest listRequest;
        private static List<PackageEntry> packageToAdd;

        private static AddRequest[] addRequests;
        private static bool[] installRequired;

        private static string PackageKeyword = "Assets/AssetStoreOriginals/_SNAPS_PrototypingAssets/";


        [InitializeOnLoadMethod]
        static void CheckPackage()
        {
            string filePath = Application.dataPath + "/../Library/PackageChecked";

 
            packageToAdd = new List<PackageEntry>();
            listRequest = null;

             
            if (!File.Exists(filePath))
            {
                var packageListFile = Directory.GetFiles(Application.dataPath, "PackageImportList.txt", SearchOption.AllDirectories);
                if (packageListFile.Length == 0)
                {
                    Debug.LogError("[Auto Package] : Couldn't find the packages list. Be sure there is a file called PackageImportList in your project");
                }
                else
                {
                    string packageListPath = packageListFile[0];
                    packageToAdd = new List<PackageEntry>();
                    string[] content = File.ReadAllLines(packageListPath);
                    foreach (var line in content)
                    {
                        var split = line.Split('@');
                        PackageEntry entry = new PackageEntry();

                        entry.name = split[0];
                        entry.version = split.Length > 1 ? split[1] : null;

                        packageToAdd.Add(entry);
                    }

                    File.WriteAllText(filePath, "Delete this to trigger a new auto package check");

                    listRequest = Client.List();

                    while (!listRequest.IsCompleted)
                    {
                        if (listRequest.Status == StatusCode.Failure || listRequest.Error != null)
                        {
                            Debug.LogError(listRequest.Error.message);
                            break;
                        }
                    }

                    addRequests = new AddRequest[packageToAdd.Count];

                    installRequired = new bool[packageToAdd.Count];

                    for (int i = 0; i < installRequired.Length; i++)
                        installRequired[i] = true;

                     
                    
                    foreach (var package in listRequest.Result)
                    {
                        for (int i = 0; i < packageToAdd.Count; i++)
                        {
                            if (package.packageId.Contains(packageToAdd[i].name))
                            {
                                installRequired[i] = false;

                                if (package.versions.latestCompatible != "" && package.version != "")
                                {

                                    if (GreaterThan(package.versions.latestCompatible, package.version))
                                    {
                                        installRequired[i] = EditorUtility.DisplayDialog("Confirm Package Upgrade", string.Format("The version of \"{0}\" in this project is not the latest version. Would you like to upgrade it to the latest version? (Recommmended)", packageToAdd[i].name), "Yes", "No");

                                        if (installRequired[i])
                                            packageToAdd[i].version = package.versions.latestCompatible;

                                    }
                                }
                            }
                        }

                    }
                

                    for (int i = 0; i < packageToAdd.Count; i++)
                    {
                        if (installRequired[i])
                            addRequests[i] = InstallSelectedPackage(packageToAdd[i].name, packageToAdd[i].version);
                    }


                    
                    ReimportPackagesByKeyword();


                }
            }
        }


        static AddRequest InstallSelectedPackage(string packageName, string packageVersion)
        {

            if (packageVersion != null)
                packageName = packageName + "@" + packageVersion;


            AddRequest newPackage = Client.Add(packageName);

            while (!newPackage.IsCompleted)
            {
                if (newPackage.Status == StatusCode.Failure || newPackage.Error != null)
                {
                    Debug.LogError(newPackage.Error.message);
                    return null;
                }
            }

            return newPackage;
        }
     
     

        static void ReimportPackagesByKeyword()
        {

            AssetDatabase.Refresh();
            AssetDatabase.ImportAsset(PackageKeyword, ImportAssetOptions.ImportRecursive);

        }

         

        static private bool GreaterThan(string versionA, string versionB)
        {
            var versionASplit = versionA.Split('.');
            var versionBSplit = versionB.Split('.');

            int previewA = 0;
            int previewB = 0;
            int patchA = 0;
            int patchB = 0;

            var majorA = Convert.ToInt32(versionASplit[0]);
            var minorA = Convert.ToInt32(versionASplit[1]);
            if (versionASplit.Length > 3)
            {
                patchA = Convert.ToInt32(versionASplit[2].Substring(0, versionASplit[2].Length - 8));
                previewA = Convert.ToInt32(versionASplit[3]);
            }
            else
            {
                patchA = Convert.ToInt32(versionASplit[2]);
            }

            var majorB = Convert.ToInt32(versionBSplit[0]);
            var minorB = Convert.ToInt32(versionBSplit[1]);
            if (versionBSplit.Length > 3)
            {
                patchA = Convert.ToInt32(versionBSplit[2].Substring(0, versionBSplit[2].Length - 8));
                previewA = Convert.ToInt32(versionBSplit[3]);
            }
            else
            {
                patchA = Convert.ToInt32(versionBSplit[2]);
            }

            if (versionASplit.Length > 3 && versionBSplit.Length > 3)
                return (majorA >= majorB && minorA >= minorB && patchA >= patchB && previewA > previewB);

            return (majorA >= majorB && minorA >= minorB && patchA > patchB);
        }



        public class PackageEntry
        {
            public string name;
            public string version;
        }


    }
}