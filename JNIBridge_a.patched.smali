.class final Lbitter/jnibridge/JNIBridge$a;
.super Ljava/lang/Object;

# interfaces
.implements Ljava/lang/reflect/InvocationHandler;


# annotations
.annotation system Ldalvik/annotation/EnclosingClass;
    value = Lbitter/jnibridge/JNIBridge;
.end annotation

.annotation system Ldalvik/annotation/InnerClass;
    accessFlags = 0xa
    name = "a"
.end annotation


# instance fields
.field private a:Ljava/lang/Object;

.field private b:J


# direct methods
.method public constructor <init>(J)V
    .locals 1

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    const/4 v0, 0x0

    new-array v0, v0, [Ljava/lang/Object;

    iput-object v0, p0, Lbitter/jnibridge/JNIBridge$a;->a:Ljava/lang/Object;

    iput-wide p1, p0, Lbitter/jnibridge/JNIBridge$a;->b:J

    return-void
.end method



# TESL-reborn patch: tolerate default interface methods that newer Android versions add
# (e.g. ServiceConnection.onServiceConnected(ComponentName, IBinder, IBinderSession) on Android 16),
# which the Unity 2017 bridge has no managed implementation for.
.method private final b(Ljava/lang/Class;Ljava/lang/reflect/Method;[Ljava/lang/Object;)Ljava/lang/Object;
    .locals 8

    iget-wide v6, p0, Lbitter/jnibridge/JNIBridge$a;->b:J

    :try_start_0
    invoke-static {v6, v7, p1, p2, p3}, Lbitter/jnibridge/JNIBridge;->invoke(JLjava/lang/Class;Ljava/lang/reflect/Method;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v0
    :try_end_0
    .catch Ljava/lang/NoSuchMethodError; {:try_start_0 .. :try_end_0} :catch_0

    return-object v0

    :catch_0
    move-exception v0

    invoke-virtual {p2}, Ljava/lang/reflect/Method;->getName()Ljava/lang/String;

    move-result-object v1

    const-string v2, "onServiceConnected"

    invoke-virtual {v1, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-eqz v1, :cond_fallback

    if-eqz p3, :cond_fallback

    array-length v1, p3

    const/4 v3, 0x3

    if-ne v1, v3, :cond_fallback

    const/4 v1, 0x2

    new-array v1, v1, [Ljava/lang/Class;

    const-class v3, Landroid/content/ComponentName;

    const/4 v4, 0x0

    aput-object v3, v1, v4

    const-class v3, Landroid/os/IBinder;

    const/4 v4, 0x1

    aput-object v3, v1, v4

    :try_start_1
    invoke-virtual {p1, v2, v1}, Ljava/lang/Class;->getMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;

    move-result-object v1

    const/4 v3, 0x2

    new-array v3, v3, [Ljava/lang/Object;

    const/4 v4, 0x0

    aget-object v5, p3, v4

    aput-object v5, v3, v4

    const/4 v4, 0x1

    aget-object v5, p3, v4

    aput-object v5, v3, v4

    invoke-static {v6, v7, p1, v1, v3}, Lbitter/jnibridge/JNIBridge;->invoke(JLjava/lang/Class;Ljava/lang/reflect/Method;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v0
    :try_end_1
    .catch Ljava/lang/Throwable; {:try_start_1 .. :try_end_1} :catch_1

    return-object v0

    :catch_1
    move-exception v0

    :cond_fallback
    invoke-virtual {p2}, Ljava/lang/reflect/Method;->getReturnType()Ljava/lang/Class;

    move-result-object v1

    sget-object v2, Ljava/lang/Void;->TYPE:Ljava/lang/Class;

    if-ne v1, v2, :cond_rethrow

    const/4 v0, 0x0

    return-object v0

    :cond_rethrow
    throw v0
.end method


# virtual methods
.method public final a()V
    .locals 3

    iget-object v0, p0, Lbitter/jnibridge/JNIBridge$a;->a:Ljava/lang/Object;

    monitor-enter v0

    const-wide/16 v1, 0x0

    :try_start_0
    iput-wide v1, p0, Lbitter/jnibridge/JNIBridge$a;->b:J

    monitor-exit v0

    return-void

    :catchall_0
    move-exception v1

    monitor-exit v0
    :try_end_0
    .catchall {:try_start_0 .. :try_end_0} :catchall_0

    throw v1
.end method

.method public final finalize()V
    .locals 6

    iget-object v0, p0, Lbitter/jnibridge/JNIBridge$a;->a:Ljava/lang/Object;

    monitor-enter v0

    :try_start_0
    iget-wide v1, p0, Lbitter/jnibridge/JNIBridge$a;->b:J

    const-wide/16 v3, 0x0

    cmp-long v5, v1, v3

    if-nez v5, :cond_0

    monitor-exit v0

    return-void

    :cond_0
    iget-wide v1, p0, Lbitter/jnibridge/JNIBridge$a;->b:J

    invoke-static {v1, v2}, Lbitter/jnibridge/JNIBridge;->delete(J)V

    monitor-exit v0

    return-void

    :catchall_0
    move-exception v1

    monitor-exit v0
    :try_end_0
    .catchall {:try_start_0 .. :try_end_0} :catchall_0

    throw v1
.end method

.method public final invoke(Ljava/lang/Object;Ljava/lang/reflect/Method;[Ljava/lang/Object;)Ljava/lang/Object;
    .locals 5

    iget-object p1, p0, Lbitter/jnibridge/JNIBridge$a;->a:Ljava/lang/Object;

    monitor-enter p1

    :try_start_0
    iget-wide v0, p0, Lbitter/jnibridge/JNIBridge$a;->b:J

    const-wide/16 v2, 0x0

    cmp-long v4, v0, v2

    if-nez v4, :cond_0

    const/4 p2, 0x0

    monitor-exit p1

    return-object p2

    :cond_0
    iget-wide v0, p0, Lbitter/jnibridge/JNIBridge$a;->b:J

    invoke-virtual {p2}, Ljava/lang/reflect/Method;->getDeclaringClass()Ljava/lang/Class;

    move-result-object v2

    invoke-direct {p0, v2, p2, p3}, Lbitter/jnibridge/JNIBridge$a;->b(Ljava/lang/Class;Ljava/lang/reflect/Method;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object p2

    monitor-exit p1

    return-object p2

    :catchall_0
    move-exception p2

    monitor-exit p1
    :try_end_0
    .catchall {:try_start_0 .. :try_end_0} :catchall_0

    throw p2
.end method
