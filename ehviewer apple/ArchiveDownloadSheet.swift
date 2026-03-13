//
//  ArchiveDownloadSheet.swift
//  ehviewer apple
//
//  H@H 归档下载选择器 - 分辨率选择与下载
//

import SwiftUI
import EhModels
import EhAPI

// MARK: - Archive Download Sheet

struct ArchiveDownloadSheet: View {
    let gid: Int64
    let token: String
    let archiveUrl: String?
    
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var archiveList: ArchiveListResult?
    @State private var selectedResolution: String = "org"
    @State private var isDownloading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("正在获取归档选项...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    errorView(error)
                } else if let archives = archiveList?.archives, !archives.isEmpty {
                    resolutionList(archives)
                } else {
                    emptyView
                }
            }
            .navigationTitle("归档下载")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("下载") {
                        Task {
                            await startDownload()
                        }
                    }
                    .disabled(isDownloading || archiveList == nil)
                }
            }
        }
        .task {
            await loadArchiveList()
        }
    }
    
    // MARK: - Resolution List
    
    private func resolutionList(_ archives: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with info
            VStack(alignment: .leading, spacing: 8) {
                Text("选择下载分辨率")
                    .font(.headline)
                Text("通过 H@H (Hentai@Home) 网络下载归档文件。选择合适的分辨率可以节省空间和流量。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
            
            // Resolution options
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(archives, id: \.0) { archive in
                        resolutionButton(id: archive.0, name: archive.1)
                        if archive.0 != archives.last?.0 {
                            Divider()
                        }
                    }
                }
            }
            
            // Footer with tips
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("💡 提示")
                    .font(.caption.bold())
                Text("• Original: 原始分辨率，文件最大")
                Text("• 数字分辨率: 重采样后的分辨率，文件较小")
                Text("• 需要账户绑定 H@H 客户端才能使用")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    private func resolutionButton(id: String, name: String) -> some View {
        Button {
            selectedResolution = id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.body)
                    Text(resolutionDescription(id))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedResolution == id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Views
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text(error)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task {
                    await loadArchiveList()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("没有可用的归档选项")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private func resolutionDescription(_ id: String) -> String {
        switch id {
        case "org":
            return "原始分辨率 (文件最大，质量最好)"
        case let res where res.contains("780"):
            return "780px 宽度 (适合手机)"
        case let res where res.contains("980"):
            return "980px 宽度 (适合小屏设备)"
        case let res where res.contains("1280"):
            return "1280px 宽度 (适合平板)"
        case let res where res.contains("1600"):
            return "1600px 宽度 (高清)"
        case let res where res.contains("2400"):
            return "2400px 宽度 (超高清)"
        default:
            return "重采样分辨率"
        }
    }
    
    // MARK: - Network Methods
    
    private func loadArchiveList() async {
        guard let archiveUrl = archiveUrl, !archiveUrl.isEmpty else {
            await MainActor.run {
                errorMessage = "画廊没有归档下载链接"
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let result = try await EhAPI.shared.getArchiveList(
                url: archiveUrl,
                gid: gid,
                token: token
            )
            
            await MainActor.run {
                // 如果返回的归档列表为空，显示错误
                if result.archives.isEmpty {
                    errorMessage = "该画廊没有可用的归档下载选项"
                } else {
                    archiveList = result
                    // 默认选择第一个选项
                    selectedResolution = result.archives[0].0
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "加载失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func startDownload() async {
        guard let archiveList = archiveList, !archiveList.paramOr.isEmpty else {
            await MainActor.run {
                errorMessage = "缺少必要的下载参数"
            }
            return
        }
        
        await MainActor.run {
            isDownloading = true
        }
        
        do {
            try await EhAPI.shared.downloadArchive(
                gid: gid,
                token: token,
                or: archiveList.paramOr,
                res: selectedResolution
            )
            
            await MainActor.run {
                isDownloading = false
                dismiss()
                // 显示成功提示
                // TODO: 添加实际的下载任务到队列
            }
        } catch EhError.noHathClient {
            await MainActor.run {
                errorMessage = "没有可用的 H@H 客户端\n\n您需要在 E-Hentai 账户中绑定一个 Hentai@Home 客户端才能使用归档下载功能。\n\n请访问 E-Hentai 网站设置 H@H 客户端。"
                isDownloading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "下载失败: \(error.localizedDescription)"
                isDownloading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ArchiveDownloadSheet(
        gid: 123456,
        token: "test_token",
        archiveUrl: "https://e-hentai.org/archiver.php?gid=123456&token=test_token"
    )
}
