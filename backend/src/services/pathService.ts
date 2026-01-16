import { PrismaClient, Prisma } from '@prisma/client';
import { CourseCategory, Difficulty } from '@ai-learning/shared';

const prisma = new PrismaClient();

// 定义包含 chapters 的 Course 类型
type CourseWithChapters = Prisma.CourseGetPayload<{
  include: { chapters: true };
}>;

// 课程依赖关系映射
const courseDependencies: Record<string, string[]> = {
  'DEEP_LEARNING': ['ML_BASICS'],
  'NLP': ['ML_BASICS'],
  'LLM': ['DEEP_LEARNING', 'NLP'],
  'AI_TOOLS': ['LLM'],
};

// 难度排序
const difficultyOrder = {
  'BEGINNER': 1,
  'INTERMEDIATE': 2,
  'ADVANCED': 3,
};

export async function generateLearningPath(
  interests: string[],
  currentLevel: string = 'BEGINNER'
): Promise<any> {
  // 获取所有相关课程
  const allCourses = await prisma.course.findMany({
    where: {
      category: {
        in: interests,
      },
    },
    include: {
      chapters: {
        orderBy: { order: 'asc' },
      },
    },
    orderBy: [
      { difficulty: 'asc' },
      { createdAt: 'asc' },
    ],
  });

  // 构建课程依赖图
  const courseMap = new Map<string, CourseWithChapters>(allCourses.map((c: CourseWithChapters) => [c.id, c]));
  const sortedCourses: CourseWithChapters[] = [];
  const visited = new Set<string>();
  const visiting = new Set<string>();

  // 拓扑排序函数
  function visit(courseId: string) {
    if (visiting.has(courseId)) {
      return; // 避免循环依赖
    }
    if (visited.has(courseId)) {
      return;
    }

    const course = courseMap.get(courseId);
    if (!course) return;

    visiting.add(courseId);

    // 先访问依赖课程
    const deps = courseDependencies[course.category] || [];
    for (const depCategory of deps) {
      const depCourses = allCourses.filter((c: CourseWithChapters) => 
        c.category === depCategory && 
        difficultyOrder[c.difficulty as keyof typeof difficultyOrder] <= 
        difficultyOrder[course.difficulty as keyof typeof difficultyOrder]
      );
      for (const depCourse of depCourses) {
        visit(depCourse.id);
      }
    }

    visiting.delete(courseId);
    visited.add(courseId);
    sortedCourses.push(course);
  }

  // 对每个兴趣领域的课程进行排序
  for (const interest of interests) {
    const interestCourses = allCourses.filter((c: CourseWithChapters) => c.category === interest);
    for (const course of interestCourses) {
      visit(course.id);
    }
  }

  // 过滤掉不符合当前水平的课程
  const userLevel = difficultyOrder[currentLevel as keyof typeof difficultyOrder];
  const filteredCourses = sortedCourses.filter((course: CourseWithChapters) => {
    const courseLevel = difficultyOrder[course.difficulty as keyof typeof difficultyOrder];
    return courseLevel <= userLevel + 1; // 允许高一级的课程
  });

  // 创建学习路径
  const pathName = `个性化学习路径 - ${interests.join(', ')}`;
  const pathDescription = `基于您的兴趣领域 ${interests.join('、')} 和当前水平 ${currentLevel} 生成的学习路径`;
  
  const path = await prisma.learningPath.create({
    data: {
      name: pathName,
      description: pathDescription,
      targetAudience: `水平: ${currentLevel}`,
      pathItems: {
        create: filteredCourses.flatMap((course: CourseWithChapters, courseIndex: number) => {
          const items: Array<{
            courseId: string;
            chapterId?: string;
            order: number;
            type: string;
          }> = [];
          // 添加课程节点
          items.push({
            courseId: course.id,
            order: courseIndex * 100,
            type: 'course',
          });
          // 添加章节节点
          course.chapters.forEach((chapter, chapterIndex: number) => {
            items.push({
              courseId: course.id,
              chapterId: chapter.id,
              order: courseIndex * 100 + chapterIndex + 1,
              type: 'chapter',
            });
          });
          return items;
        }),
      },
    },
    include: {
      pathItems: {
        include: {
          course: true,
          chapter: true,
        },
        orderBy: { order: 'asc' },
      },
    },
  });

  return path;
}
