using UnityEditor;
using UnityEngine;
using UnityEngine.UIElements;

namespace __NAMESPACE__.Editor
{
    public class PackageDoctorWindow : EditorWindow
    {
        [MenuItem("Tools/__DISPLAY__/Package Doctor")]
        public static void ShowWindow()
        {
            PackageDoctorWindow wnd = GetWindow<PackageDoctorWindow>();
            wnd.titleContent = new GUIContent("Package Doctor");
        }

        public void CreateGUI()
        {
            VisualElement root = rootVisualElement;

            var title = new Label("Package Doctor");
            title.style.fontSize = 20;
            title.style.unityFontStyleAndWeight = FontStyle.Bold;
            root.Add(title);

            var info = new Label("Check the health of your __DISPLAY__ package.");
            root.Add(info);

            var button = new Button(() => Debug.Log("Running diagnostics...")) { text = "Run Diagnostics" };
            root.Add(button);
        }
    }
}
