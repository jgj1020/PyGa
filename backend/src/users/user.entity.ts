import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  Unique,
} from "typeorm";

@Entity("users")
@Unique(["email"])
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 30 })
  nickname: string;

  @Column({ length: 100 })
  email: string;

  @Column()
  password: string;

  @Column({ name: "is_admin", default: false })
  isAdmin: boolean;

  @Column({ type: "text", nullable: true })
  avatar: string | null;

  @Column({ name: "suspended_until", type: "timestamptz", nullable: true })
  suspendedUntil: Date | null;

  @Column({ name: "suspension_permanent", default: false })
  suspensionPermanent: boolean;

  @Column({ name: "suspension_reason", type: "text", nullable: true })
  suspensionReason: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
