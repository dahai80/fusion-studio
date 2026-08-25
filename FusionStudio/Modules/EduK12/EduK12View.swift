import SwiftUI
import os

struct EduK12View: View {
    @State private var selectedGrade: String = ""
    @State private var selectedCourse: CourseItem?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            GradeSelectView(selectedGrade: $selectedGrade, navigationPath: $navigationPath)
                .navigationTitle("教育")
                .navigationDestination(for: CourseItem.self) { course in
                    CourseMapView(grade: course.grade, course: course, navigationPath: $navigationPath)
                }
                .navigationDestination(for: LessonItem.self) { lesson in
                    LessonPlayerView(lesson: lesson)
                }
        }
    }
}

struct GradeSelectView: View {
    @Binding var selectedGrade: String
    @Binding var navigationPath: NavigationPath
    @State private var courses: [CourseItem] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(grades, id: \.id) { grade in
                    GradeCard(grade: grade) {
                        loadCourses(for: grade.id)
                    }
                }
            }
            .padding()
        }
        .task { await loadAllCourses() }
    }

    private func loadCourses(for gradeId: String) {
        let filtered = allCourses.filter { $0.grade == gradeId }
        if let first = filtered.first {
            navigationPath.append(first)
        }
    }

    private func loadAllCourses() async {
        guard let url = URL(string: "http://localhost:3000/api/courses?grade=\(selectedGrade)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = json["courses"] as? [[String: Any]] {
                courses = list.compactMap { item in
                    guard let id = item["id"] as? String,
                          let title = item["title"] as? String,
                          let grade = item["grade"] as? String else { return nil }
                    return CourseItem(id: id, title: title, grade: grade, units: (item["units"] as? [[String: Any]])?.compactMap { u in
                        guard let uid = u["id"] as? String, let utitle = u["title"] as? String else { return nil }
                        return UnitItem(id: uid, title: utitle, topics: u["topics"] as? [String] ?? [])
                    } ?? [])
                }
            }
        } catch {
            logger.error("Failed to load courses: \(error)")
        }
    }
}

struct GradeCard: View {
    let grade: GradeInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: grade.icon)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(grade.color)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(grade.name)
                        .font(.headline)
                    Text(grade.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct CourseMapView: View {
    let grade: String
    let course: CourseItem
    @Binding var navigationPath: NavigationPath
    @State private var gamification: GamificationState?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let gam = gamification {
                    GamificationBar(state: gam)
                }

                ForEach(course.units, id: \.id) { unit in
                    UnitSection(unit: unit, navigationPath: $navigationPath)
                }
            }
            .padding()
        }
        .navigationTitle(course.title)
        .task { await loadGamification() }
    }

    private func loadGamification() async {
        guard let url = URL(string: "http://localhost:3000/api/gamification/default") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                gamification = GamificationState(
                    stars: json["stars"] as? Int ?? 0,
                    level: json["level"] as? Int ?? 1,
                    xp: json["xp"] as? Int ?? 0,
                    streakDays: json["streak_days"] as? Int ?? 0
                )
            }
        } catch {
            logger.error("Failed to load gamification: \(error)")
        }
    }
}

struct GamificationBar: View {
    let state: GamificationState

    var body: some View {
        HStack(spacing: 20) {
            Label("\(state.stars) ⭐", systemImage: "star.fill")
                .foregroundColor(.yellow)
            Label("Lv.\(state.level)", systemImage: "chart.bar.fill")
                .foregroundColor(.blue)
            Label("\(state.xp) XP", systemImage: "bolt.fill")
                .foregroundColor(.orange)
            Label("\(state.streakDays) 天", systemImage: "flame.fill")
                .foregroundColor(.red)
        }
        .font(.subheadline)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct UnitSection: View {
    let unit: UnitItem
    @Binding var navigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(unit.title)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                ForEach(unit.topics, id: \.self) { topic in
                    Button {
                        let lesson = LessonItem(id: "\(unit.id)-\(topic)", title: topic, grade: "", unitId: unit.id)
                        navigationPath.append(lesson)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.title2)
                            Text(topic)
                                .font(.caption)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct LessonPlayerView: View {
    let lesson: LessonItem
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            WebViewContainer(
                url: "http://localhost:3000/content/\(lesson.grade)/\(lesson.id).html",
                isLoading: $isLoading,
                error: $loadError
            )

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在加载课程...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                    Text("无法加载课程")
                        .font(.title2)
                        .bold()
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text("请确保 Edu Platform 服务已启动 (localhost:3000)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadError = nil
                        isLoading = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .navigationTitle(lesson.title)
    }
}

// MARK: - Data Models

struct GradeInfo: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let color: Color
}

struct CourseItem: Hashable, Identifiable {
    let id: String
    let title: String
    let grade: String
    let units: [UnitItem]
}

struct UnitItem: Hashable, Identifiable {
    let id: String
    let title: String
    let topics: [String]
}

struct LessonItem: Hashable, Identifiable {
    let id: String
    let title: String
    let grade: String
    let unitId: String
}

struct GamificationState {
    let stars: Int
    let level: Int
    let xp: Int
    let streakDays: Int
}

// MARK: - Static Data

private let grades: [GradeInfo] = [
    GradeInfo(id: "grade-2", name: "二年级", subtitle: "加减法 · 乘法 · 长度 · 观察", icon: "2.circle.fill", color: .green),
    GradeInfo(id: "grade-6", name: "六年级", subtitle: "圆 · 百分数 · 比例 · 圆柱圆锥", icon: "6.circle.fill", color: .blue),
    GradeInfo(id: "grade-7", name: "初一", subtitle: "有理数 · 方程 · 几何初步", icon: "7.circle.fill", color: .purple),
    GradeInfo(id: "grade-8", name: "初二", subtitle: "函数 · 三角形 · 物理", icon: "8.circle.fill", color: .orange),
    GradeInfo(id: "grade-9", name: "初三", subtitle: "二次函数 · 圆 · 电磁", icon: "9.circle.fill", color: .red),
]

private let allCourses: [CourseItem] = [
    CourseItem(id: "math-g2", title: "二年级数学（北师大版）", grade: "grade-2", units: [
        UnitItem(id: "g2-u1", title: "长度单位", topics: ["厘米认识", "米认识", "测量"]),
        UnitItem(id: "g2-u2", title: "100以内加减法", topics: ["进位加", "退位减"]),
        UnitItem(id: "g2-u3", title: "表内乘法", topics: ["乘法口诀", "意义理解"]),
        UnitItem(id: "g2-u4", title: "观察物体", topics: ["正面", "侧面", "上面"]),
    ]),
    CourseItem(id: "math-g6", title: "六年级数学（北师大版）", grade: "grade-6", units: [
        UnitItem(id: "g6-u1", title: "圆", topics: ["圆的认识", "周长", "面积"]),
        UnitItem(id: "g6-u2", title: "百分数", topics: ["百分数意义", "应用"]),
        UnitItem(id: "g6-u3", title: "比例", topics: ["正比例", "反比例"]),
        UnitItem(id: "g6-u4", title: "圆柱与圆锥", topics: ["侧面积", "体积"]),
    ]),
]

private let logger = Logger(subsystem: "com.fusion.studio", category: "EduK12")
