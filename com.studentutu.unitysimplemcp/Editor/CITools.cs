using UnityEditor;
using UnityEditor.Compilation;
using UnityEngine;

namespace SimpleUnityMCP.Editor
{
    public static class CiTools
    {
        public const string ProjectFilesSyncedMarker = "SIMPLE_UNITY_MCP_CI:PROJECT_FILES_SYNCED";
        public const string CompilationPassedMarker = "SIMPLE_UNITY_MCP_CI:COMPILATION_PASSED";

        private const string CompilationPendingKey = "SimpleUnityMCP.CI.CompilationPending";
        private const string CompilationErrorCountKey = "SimpleUnityMCP.CI.CompilationErrorCount";

        [InitializeOnLoadMethod]
        private static void ResumePendingCompilationAfterDomainReload()
        {
            if (SessionState.GetBool(CompilationPendingKey, false))
                EditorApplication.update += CompleteCompilationWhenEditorIsIdle;
        }

        // Force Unity to fully recompile scripts (clean build cache + compile),
        // then quit the editor when it's done so your bash step can continue.
        // Invoke as SimpleUnityMCP.Editor.CiTools.ForceCompileAndExit.
        public static void ForceCompileAndExit()
        {
            SessionState.SetBool(CompilationPendingKey, true);
            SessionState.SetInt(CompilationErrorCountKey, 0);
            RegisterCompilationCallbacks();

            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport | ImportAssetOptions.ForceUpdate);
            CompilationPipeline.RequestScriptCompilation(
                RequestScriptCompilationOptions.CleanBuildCache
            );
        }

        private static void RegisterCompilationCallbacks()
        {
            CompilationPipeline.assemblyCompilationFinished -= OnAssemblyCompilationFinished;
            CompilationPipeline.compilationFinished -= OnCompilationFinished;
            CompilationPipeline.assemblyCompilationFinished += OnAssemblyCompilationFinished;
            CompilationPipeline.compilationFinished += OnCompilationFinished;
        }

        private static void OnAssemblyCompilationFinished(string assemblyPath, CompilerMessage[] messages)
        {
            var errorCount = SessionState.GetInt(CompilationErrorCountKey, 0);

            foreach (var message in messages)
            {
                if (message.type != CompilerMessageType.Error)
                    continue;

                errorCount++;
                Debug.LogError($"{assemblyPath}: {message.message} ({message.file}:{message.line}:{message.column})");
            }

            SessionState.SetInt(CompilationErrorCountKey, errorCount);
        }

        private static void OnCompilationFinished(object context)
        {
            CompilationPipeline.assemblyCompilationFinished -= OnAssemblyCompilationFinished;
            CompilationPipeline.compilationFinished -= OnCompilationFinished;
            EditorApplication.update += CompleteCompilationWhenEditorIsIdle;
        }

        private static void CompleteCompilationWhenEditorIsIdle()
        {
            if (!SessionState.GetBool(CompilationPendingKey, false))
            {
                EditorApplication.update -= CompleteCompilationWhenEditorIsIdle;
                return;
            }

            if (EditorApplication.isCompiling || EditorApplication.isUpdating)
                return;

            EditorApplication.update -= CompleteCompilationWhenEditorIsIdle;
            CompilationPipeline.assemblyCompilationFinished -= OnAssemblyCompilationFinished;
            CompilationPipeline.compilationFinished -= OnCompilationFinished;

            var compilationErrorCount = SessionState.GetInt(CompilationErrorCountKey, 0);
            SessionState.SetBool(CompilationPendingKey, false);
            SessionState.SetInt(CompilationErrorCountKey, 0);

            if (compilationErrorCount == 0)
                Debug.Log(CompilationPassedMarker);
            else
                Debug.LogError($"SIMPLE_UNITY_MCP_CI:COMPILATION_FAILED errors={compilationErrorCount}");

            EditorApplication.Exit(compilationErrorCount == 0 ? 0 : 1);
        }

        // Regenerate IDE project files (.sln/.csproj), then quit.
        // The command line owns process shutdown via -quit; this method emits a marker
        // only after the refresh and IDE sync both complete.
        public static void RegenerateProjectFilesAndExit()
        {
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport | ImportAssetOptions.ForceUpdate);
            Unity.CodeEditor.CodeEditor.CurrentEditor.SyncAll();
            Debug.Log(ProjectFilesSyncedMarker);
        }
    }
}
