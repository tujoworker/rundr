import SwiftUI

struct CompanionIntroView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme
    @State private var selectedPage = 0

    private var pages: [CompanionIntroPage] {
        [
            CompanionIntroPage(
                icon: "applewatch",
                title: L10n.introStartOnWatchTitle,
                body: L10n.introStartOnWatchBody
            ),
            CompanionIntroPage(
                icon: "ruler",
                title: L10n.introPlanTitle,
                body: L10n.introPlanBody
            ),
            CompanionIntroPage(
                icon: "figure.run.circle",
                title: L10n.introLapsTitle,
                body: L10n.introLapsBody
            ),
            CompanionIntroPage(
                icon: "figure.walk.motion",
                title: L10n.introRestTitle,
                body: L10n.introRestBody
            ),
            CompanionIntroPage(
                icon: "arrow.trianglehead.2.clockwise.rotate.90",
                title: L10n.introSyncAndRepeatTitle,
                body: L10n.introSyncAndRepeatBody
            )
        ]
    }

    private var pageIndicatorView: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, _ in
                Circle()
                    .fill(index == selectedPage ? theme.text.neutral : theme.text.subtle)
                    .frame(
                        width: index == selectedPage ? Tokens.Spacing.sm : Tokens.Spacing.xs,
                        height: index == selectedPage ? Tokens.Spacing.sm : Tokens.Spacing.xs
                    )
            }
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .padding(.vertical, Tokens.Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.introPageLabel(selectedPage + 1, pages.count))
    }

    var body: some View {
        TabView(selection: $selectedPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: Tokens.Spacing.xxxxl) {
                            Spacer(minLength: Tokens.Spacing.xxxxl)

                            ZStack {
                                Circle()
                                    .fill(theme.background.emphasisAction(settings.primaryAccentColor))

                                Image(systemName: page.icon)
                                    .font(.system(size: 46, weight: .semibold))
                                    .foregroundStyle(theme.text.emphasis)
                            }
                            .frame(
                                width: Tokens.ControlSize.companionFeatureBadge,
                                height: Tokens.ControlSize.companionFeatureBadge
                            )

                            VStack(spacing: Tokens.Spacing.xl) {
                                Text(page.title)
                                    .font(.title.bold())
                                    .foregroundStyle(theme.text.neutral)
                                    .multilineTextAlignment(.center)

                                Text(page.body)
                                    .font(.title3.weight(.regular))
                                    .foregroundStyle(theme.text.subtle)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, Tokens.Spacing.xxxxl)

                            Spacer(minLength: Tokens.Spacing.xxxxl)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: proxy.size.height)
                        .padding(.vertical, Tokens.Spacing.xxxxl)
                    }
                    .background {
                        CompanionListBackgroundView()
                            .ignoresSafeArea()
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .safeAreaInset(edge: .bottom) {
            pageIndicatorView
                .padding(.bottom, Tokens.Spacing.lg)
        }
        .navigationTitle(L10n.intro)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CompanionAboutDetailView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxxl) {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                    Text(L10n.aboutRundrHeadline)
                        .font(.title.bold())
                        .foregroundStyle(theme.text.neutral)

                    Text(L10n.aboutRundrBodyOne)
                        .font(.title3.weight(.regular))
                        .foregroundStyle(theme.text.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CompanionAboutCard(
                    icon: "slider.horizontal.3",
                    title: L10n.aboutFlexibleSessionsTitle,
                    bodyText: L10n.aboutFlexibleSessionsBody
                )

                CompanionAboutCard(
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    title: L10n.aboutKeepMomentumTitle,
                    bodyText: L10n.aboutKeepMomentumBody
                )
            }
            .padding(.horizontal, Tokens.Spacing.xxxl)
            .padding(.vertical, Tokens.Spacing.xxxl)
        }
        .background {
            CompanionListBackgroundView()
                .ignoresSafeArea()
        }
        .navigationTitle(L10n.about)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CompanionHelpView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    private var topics: [CompanionHelpTopic] {
        [
            CompanionHelpTopic(
                id: L10n.helpSessionPlanTitle,
                icon: "square.stack.3d.down.right",
                title: L10n.helpSessionPlanTitle,
                body: L10n.helpSessionPlanBody,
                sections: [],
                example: L10n.helpSessionPlanExample,
                tip: nil
            ),
            CompanionHelpTopic(
                id: L10n.helpRestTitle,
                icon: "figure.walk.motion",
                title: L10n.helpRestTitle,
                body: L10n.helpRestBody,
                sections: [
                    CompanionHelpSection(
                        title: L10n.helpRestTimedHeading,
                        body: L10n.helpRestTimedBody,
                        example: nil,
                        tip: nil
                    ),
                    CompanionHelpSection(
                        title: L10n.helpRestActiveRecoveryHeading,
                        body: L10n.helpRestActiveRecoveryBody,
                        example: nil,
                        tip: nil
                    )
                ],
                example: nil,
                tip: L10n.helpRestTip
            ),
            CompanionHelpTopic(
                id: L10n.helpAutoRestTitle,
                icon: "figure.run.circle",
                title: L10n.helpAutoRestTitle,
                body: L10n.helpAutoRestBody,
                sections: [],
                example: L10n.helpAutoRestExample,
                tip: nil
            ),
            CompanionHelpTopic.activeRecovery,
            CompanionHelpTopic.lastRest,
            CompanionHelpTopic(
                id: L10n.helpDistanceTypeTitle,
                icon: "road.lanes",
                title: L10n.helpDistanceTypeTitle,
                body: nil,
                sections: [
                    CompanionHelpSection(
                        title: L10n.helpDistanceTypeFixedHeading,
                        body: L10n.helpDistanceTypeFixedBody,
                        example: nil,
                        tip: nil
                    ),
                    CompanionHelpSection(
                        title: L10n.helpDistanceTypeOpenHeading,
                        body: L10n.helpDistanceTypeOpenBody,
                        example: L10n.helpDistanceTypeOpenExample,
                        tip: nil
                    )
                ],
                example: nil,
                tip: nil
            ),
            CompanionHelpTopic(
                id: L10n.helpAppleHealthTitle,
                icon: "heart.text.square",
                title: L10n.helpAppleHealthTitle,
                body: L10n.helpAppleHealthBody,
                sections: [],
                example: L10n.helpAppleHealthExample,
                tip: nil
            ),
            CompanionHelpTopic(
                id: L10n.helpAppleActivityTitle,
                icon: "chart.line.uptrend.xyaxis",
                title: L10n.helpAppleActivityTitle,
                body: L10n.helpAppleActivityBody,
                sections: [],
                example: nil,
                tip: L10n.helpAppleActivityTip
            ),
            CompanionHelpTopic(
                id: L10n.helpSharingTitle,
                icon: "square.and.arrow.up.on.square",
                title: L10n.helpSharingTitle,
                body: L10n.helpSharingBody,
                sections: [
                    CompanionHelpSection(
                        title: L10n.helpSharingSendHeading,
                        body: L10n.helpSharingSendBody,
                        example: nil,
                        tip: nil
                    ),
                    CompanionHelpSection(
                        title: L10n.helpSharingReceiveHeading,
                        body: L10n.helpSharingReceiveBody,
                        example: L10n.helpSharingReceiveExample,
                        tip: nil
                    )
                ],
                example: nil,
                tip: L10n.helpSharingTip
            )
        ]
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xxxl) {
                    CompanionHelpOverviewCard(topics: topics) { topicID in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(topicID, anchor: .top)
                        }
                    }

                    ForEach(topics) { topic in
                        CompanionHelpCard(topic: topic)
                            .id(topic.id)
                    }
                }
                .padding(.horizontal, Tokens.Spacing.xxxl)
                .padding(.vertical, Tokens.Spacing.xxxl)
            }
        }
        .background {
            CompanionListBackgroundView()
                .ignoresSafeArea()
        }
        .navigationTitle(L10n.help)
        .navigationBarTitleDisplayMode(.inline)
        .tint(settings.primaryAccentColor)
        .foregroundStyle(theme.text.neutral)
    }
}

private struct CompanionHelpOverviewCard: View {
    let topics: [CompanionHelpTopic]
    let onSelectTopic: (String) -> Void
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    private var tocItemFill: Color {
        .clear
    }

    private var tocItemStroke: Color {
        theme.isDark ? theme.stroke.callout : .clear
    }

    private var tocCardFill: Color {
        .clear
    }

    private var tocCardStroke: Color {
        theme.isDark ? theme.stroke.neutral : .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            HStack(alignment: .center, spacing: Tokens.Spacing.lg) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: Tokens.FontSize.xxl, weight: .semibold))
                    .foregroundStyle(settings.primaryAccentColor)

                Text(L10n.helpOverviewTitle)
                    .font(.system(size: Tokens.FontSize.xl, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.text.neutral)
            }

            VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                ForEach(topics) { topic in
                    Button {
                        onSelectTopic(topic.id)
                    } label: {
                        HStack(alignment: .center, spacing: Tokens.Spacing.md) {
                            Image(systemName: topic.icon)
                                .font(.system(size: Tokens.FontSize.md, weight: .semibold))
                                .foregroundStyle(settings.primaryAccentColor)
                                .frame(width: Tokens.FontSize.xl, alignment: .center)

                            Text(topic.title)
                                .font(.system(size: Tokens.FontSize.lg, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.text.neutral)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Tokens.Spacing.lg)
                        .padding(.vertical, Tokens.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                                .fill(tocItemFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                                .stroke(tocItemStroke, lineWidth: Tokens.LineWidth.thin)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.xxxl)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
                .fill(tocCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
                .stroke(tocCardStroke, lineWidth: Tokens.LineWidth.thin)
        )
    }
}

struct CompanionPrivacyPolicyView: View {
    private let sections: [CompanionLegalSection] = [
        CompanionLegalSection(
            icon: "internaldrive",
            title: L10n.privacyWhatRundrStoresTitle,
            body: L10n.privacyWhatRundrStoresBody
        ),
        CompanionLegalSection(
            icon: "slider.horizontal.3",
            title: L10n.privacyHowRundrUsesDataTitle,
            body: L10n.privacyHowRundrUsesDataBody
        ),
        CompanionLegalSection(
            icon: "arrow.trianglehead.2.clockwise.rotate.90",
            title: L10n.privacyStorageAndSyncTitle,
            body: L10n.privacyStorageAndSyncBody
        ),
        CompanionLegalSection(
            icon: "hand.raised",
            title: L10n.privacyPermissionsTitle,
            body: L10n.privacyPermissionsBody
        )
    ]

    var body: some View {
        CompanionLegalDetailView(
            title: L10n.privacyPolicy,
            sections: sections
        )
    }
}

struct CompanionTermsOfUseView: View {
    private let sections: [CompanionLegalSection] = [
        CompanionLegalSection(
            icon: "figure.run",
            title: L10n.termsScopeTitle,
            body: L10n.termsScopeBody
        ),
        CompanionLegalSection(
            icon: "cross.case",
            title: L10n.termsMedicalTitle,
            body: L10n.termsMedicalBody
        ),
        CompanionLegalSection(
            icon: "exclamationmark.triangle",
            title: L10n.termsSafetyTitle,
            body: L10n.termsSafetyBody
        ),
        CompanionLegalSection(
            icon: "shield.lefthalf.filled",
            title: L10n.termsResponsibilityTitle,
            body: L10n.termsResponsibilityBody
        ),
        CompanionLegalSection(
            icon: "gearshape.2",
            title: L10n.termsAvailabilityTitle,
            body: L10n.termsAvailabilityBody
        )
    ]

    var body: some View {
        CompanionLegalDetailView(
            title: L10n.termsOfUse,
            sections: sections
        )
    }
}

private struct CompanionLegalDetailView: View {
    let title: String
    let sections: [CompanionLegalSection]
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxl) {
                ForEach(sections) { section in
                    CompanionLegalSectionCard(section: section)
                }
            }
            .padding(.horizontal, Tokens.Spacing.xxxl)
            .padding(.vertical, Tokens.Spacing.xxxl)
        }
        .background {
            CompanionListBackgroundView()
                .ignoresSafeArea()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(settings.primaryAccentColor)
        .foregroundStyle(theme.text.neutral)
        .textSelection(.enabled)
    }
}

private struct CompanionAboutCard: View {
    let icon: String
    let title: String
    let bodyText: String
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            HStack(alignment: .center, spacing: Tokens.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: Tokens.FontSize.xxl, weight: .semibold))
                    .foregroundStyle(settings.primaryAccentColor)

                Text(title)
                    .font(.system(size: Tokens.FontSize.xl, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.text.neutral)
            }

            Text(bodyText)
                .font(.title3.weight(.regular))
                .foregroundStyle(theme.text.subtle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.xxxl)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
                .fill(theme.background.history)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
                .stroke(theme.stroke.neutral, lineWidth: Tokens.LineWidth.thin)
        )
    }
}

struct CompanionHelpCard: View {
    let topic: CompanionHelpTopic
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            HStack(alignment: .center, spacing: Tokens.Spacing.lg) {
                Image(systemName: topic.icon)
                    .font(.system(size: Tokens.FontSize.xxl, weight: .semibold))
                    .foregroundStyle(settings.primaryAccentColor)

                Text(topic.title)
                    .font(.system(size: Tokens.FontSize.xl, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.text.neutral)
            }

            if let body = topic.body {
                Text(body)
                    .font(.title3.weight(.regular))
                    .foregroundStyle(theme.text.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(topic.sections) { section in
                CompanionHelpSectionView(section: section)
            }

            if let example = topic.example {
                CompanionHelpHighlight(
                    label: L10n.example,
                    text: example
                )
            }

            if let tip = topic.tip {
                CompanionHelpHighlight(
                    label: L10n.tip,
                    text: tip
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.xxxl)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
                .fill(theme.background.history)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
                .stroke(theme.stroke.neutral, lineWidth: Tokens.LineWidth.thin)
        )
    }
}

private struct CompanionHelpSectionView: View {
    let section: CompanionHelpSection
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text(section.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.text.neutral)
                .padding(.top, Tokens.Spacing.md)

            Text(section.body)
                .font(.title3.weight(.regular))
                .foregroundStyle(theme.text.subtle)
                .fixedSize(horizontal: false, vertical: true)

            if let example = section.example {
                CompanionHelpHighlight(
                    label: L10n.example,
                    text: example
                )
            }

            if let tip = section.tip {
                CompanionHelpHighlight(
                    label: L10n.tip,
                    text: tip
                )
            }
        }
    }
}

private struct CompanionHelpHighlight: View {
    let label: String
    let text: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Text(label)
                .font(.system(size: Tokens.FontSize.md, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.text.neutral)

            Text(text)
                .font(.system(size: Tokens.FontSize.lg, weight: .regular, design: .default))
                .foregroundStyle(theme.text.subtle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                .fill(theme.background.neutralAction)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                .stroke(theme.stroke.callout, lineWidth: Tokens.LineWidth.thin)
        )
    }
}

private struct CompanionIntroPage {
    let icon: String
    let title: String
    let body: String
}

struct CompanionHelpTopic: Identifiable {
    let id: String
    let icon: String
    let title: String
    let body: String?
    let sections: [CompanionHelpSection]
    let example: String?
    let tip: String?
}

struct CompanionHelpSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let example: String?
    let tip: String?
}

private struct CompanionLegalSection: Identifiable {
    let icon: String
    let title: String
    let body: String
    var id: String { title }
}

private struct CompanionLegalSectionCard: View {
    let section: CompanionLegalSection
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            HStack(alignment: .center, spacing: Tokens.Spacing.lg) {
                Image(systemName: section.icon)
                    .font(.system(size: Tokens.FontSize.xxl, weight: .semibold))
                    .foregroundStyle(settings.primaryAccentColor)

                Text(section.title)
                    .font(.system(size: Tokens.FontSize.xl, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.text.neutral)
            }

            Text(section.body)
                .font(.title3.weight(.regular))
                .foregroundStyle(theme.text.subtle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.xxxl)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
                .fill(theme.background.history)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.companionListCell, style: .continuous)
                .stroke(theme.stroke.neutral, lineWidth: Tokens.LineWidth.thin)
        )
    }
}

extension CompanionHelpTopic {
    static var activeRecovery: CompanionHelpTopic {
        CompanionHelpTopic(
            id: L10n.helpActiveRecoveryTitle,
            icon: "figure.run",
            title: L10n.helpActiveRecoveryTitle,
            body: L10n.helpActiveRecoveryBody,
            sections: [
                CompanionHelpSection(
                    title: L10n.helpActiveRecoveryTrackingHeading,
                    body: L10n.helpActiveRecoveryTrackingBody,
                    example: nil,
                    tip: nil
                ),
                CompanionHelpSection(
                    title: L10n.helpActiveRecoveryUseHeading,
                    body: L10n.helpActiveRecoveryUseBody,
                    example: nil,
                    tip: nil
                )
            ],
            example: L10n.helpActiveRecoveryExample,
            tip: nil
        )
    }

    static var lastRest: CompanionHelpTopic {
        CompanionHelpTopic(
            id: L10n.helpLastRestTitle,
            icon: "flag.checkered",
            title: L10n.helpLastRestTitle,
            body: L10n.helpLastRestBody,
            sections: [
                CompanionHelpSection(
                    title: L10n.helpLastRestWhenHeading,
                    body: L10n.helpLastRestWhenBody,
                    example: nil,
                    tip: nil
                ),
                CompanionHelpSection(
                    title: L10n.helpLastRestWhyHeading,
                    body: L10n.helpLastRestWhyBody,
                    example: nil,
                    tip: nil
                )
            ],
            example: L10n.helpLastRestExample,
            tip: nil
        )
    }

    static var distanceType: CompanionHelpTopic {
        CompanionHelpTopic(
            id: L10n.helpDistanceTypeTitle,
            icon: "road.lanes",
            title: L10n.helpDistanceTypeTitle,
            body: nil,
            sections: [
                CompanionHelpSection(
                    title: L10n.helpDistanceTypeFixedHeading,
                    body: L10n.helpDistanceTypeFixedBody,
                    example: nil,
                    tip: nil
                ),
                CompanionHelpSection(
                    title: L10n.helpDistanceTypeOpenHeading,
                    body: L10n.helpDistanceTypeOpenBody,
                    example: L10n.helpDistanceTypeOpenExample,
                    tip: nil
                )
            ],
            example: nil,
            tip: nil
        )
    }

    static var autoRest: CompanionHelpTopic {
        CompanionHelpTopic(
            id: L10n.helpAutoRestTitle,
            icon: "figure.run.circle",
            title: L10n.helpAutoRestTitle,
            body: L10n.helpAutoRestBody,
            sections: [],
            example: L10n.helpAutoRestExample,
            tip: nil
        )
    }

    static var restMode: CompanionHelpTopic {
        CompanionHelpTopic(
            id: L10n.helpRestTitle,
            icon: "figure.walk.motion",
            title: L10n.helpRestTitle,
            body: L10n.helpRestBody,
            sections: [
                CompanionHelpSection(
                    title: L10n.helpRestTimedHeading,
                    body: L10n.helpRestTimedBody,
                    example: nil,
                    tip: nil
                )
            ],
            example: nil,
            tip: L10n.helpRestTip
        )
    }
}