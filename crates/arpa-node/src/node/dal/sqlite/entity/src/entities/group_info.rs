//! SeaORM Entity. Generated by sea-orm-codegen 0.9.2

use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "group_info")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: i32,
    pub index: i32,
    pub epoch: i32,
    pub size: i32,
    pub threshold: i32,
    pub state: i32,
    pub public_key: Option<Vec<u8>>,
    pub members: String,
    pub committers: Option<String>,
    pub share: Option<Vec<u8>>,
    pub dkg_status: i32,
    pub self_member_index: i32,
    pub dkg_start_block_height: i32,
    pub create_at: String,
    pub update_at: String,
}

#[derive(Copy, Clone, Debug, EnumIter)]
pub enum Relation {}

impl RelationTrait for Relation {
    fn def(&self) -> RelationDef {
        panic!("No RelationDef")
    }
}

impl ActiveModelBehavior for ActiveModel {}
