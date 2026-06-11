import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: [SortDescriptor(\HomepagePlanRecord.generatedAt, order: .reverse)]) private var plans: [HomepagePlanRecord]
    @Binding var selectedArticleID: UUID?

    var body: some View {
        Group {
            if let plan = plans.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        HomeHeaderView(title: plan.title, subtitle: plan.subtitle)

                        ForEach(plan.sections.sorted(using: [SortDescriptor(\HomepageSectionRecord.displayOrder)])) { section in
                            VStack(alignment: .leading, spacing: 18) {
                                SectionHeaderView(title: section.title, subtitle: section.subtitle)

                                switch section.style {
                                case .hero:
                                    HeroSectionView(placements: orderedPlacements(for: section), selectedArticleID: $selectedArticleID)
                                case .grid:
                                    StoryGridSectionView(placements: orderedPlacements(for: section), selectedArticleID: $selectedArticleID)
                                case .rail:
                                    TopicRailSectionView(placements: orderedPlacements(for: section), selectedArticleID: $selectedArticleID)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 1500)
                    .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView(
                    "No Homepage Yet",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text("Refresh the feeds to generate your first editorial homepage.")
                )
            }
        }
        .background(JippoPalette.canvas.ignoresSafeArea())
        .navigationTitle("Jippo")
        .jippoTitleDisplayMode(.large)
    }

    private func orderedPlacements(for section: HomepageSectionRecord) -> [HomepagePlacementRecord] {
        section.placements.sorted(using: [SortDescriptor(\HomepagePlacementRecord.displayOrder)])
    }
}

struct HomeHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Label("Real feed sync + local persistence + editorial layout planning", systemImage: "wand.and.stars")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JippoPalette.highlight)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView(selectedArticleID: .constant(nil))
                .modelContainer(for: [
                    FeedRecord.self,
                    ArticleRecord.self,
                    ArticleContentRecord.self,
                    HomepagePlanRecord.self,
                    HomepageSectionRecord.self,
                    HomepagePlacementRecord.self
                ], inMemory: true)
                .preferredColorScheme(.dark)
        }
    }
}
