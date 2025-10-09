import SwiftUI
import Kingfisher

// MARK: - Avatar 头像视图
struct AvatarView: View {
    let urlString: String?
    var size: CGFloat = 48
    
    private var placeholder: some View {
        Circle().fill(Color.secondary.opacity(0.2))
            .overlay(
                Image(systemName: "person")
                    .imageScale(size > 60 ? .large : .medium)
                    .font(.system(size: size * 0.4))
            )
            .frame(width: size, height: size)
    }

    var body: some View {
        Group {
            if let url = URL(string: urlString ?? ""), !url.absoluteString.isEmpty {
                KFImage(url)
                    .placeholder { placeholder }
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: size * 2, height: size * 2)))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .cancelOnDisappear(true)
                    .onFailure { _ in }
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                placeholder
            }
        }
    }
}

// MARK: - 等级徽章视图
struct RankBadge: View {
    let rank: String?
    
    var body: some View {
        let title = chineseTitle(for: rank)
        let color = colorForRank(rank)
        Text(title)
            .font(.caption2).bold()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - 辅助函数

// 称号（返回英文）
func chineseTitle(for rank: String?) -> String {
    switch (rank ?? "").lowercased() {
    case "newbie": return "Newbie"
    case "pupil": return "Pupil"
    case "specialist": return "Specialist"
    case "expert": return "Expert"
    case "candidate master": return "Candidate Master"
    case "master": return "Master"
    case "international master": return "International Master"
    case "grandmaster": return "Grandmaster"
    case "international grandmaster": return "International Grandmaster"
    case "legendary grandmaster": return "Legendary Grandmaster"
    default: return "Unrated"
    }
}

func colorForRank(_ rank: String?) -> Color {
    switch (rank ?? "").lowercased() {
    case "newbie": return colorForRating(1000)
    case "pupil": return colorForRating(1300)
    case "specialist": return colorForRating(1500)
    case "expert": return colorForRating(1700)
    case "candidate master": return colorForRating(1950)
    case "master": return colorForRating(2150)
    case "international master": return colorForRating(2350)
    case "grandmaster": return colorForRating(2450)
    case "international grandmaster": return colorForRating(2650)
    case "legendary grandmaster": return colorForRating(3000)
    default: return .gray
    }
}

